#include "NavoKoggerEchogramItem.h"
#include "NavoKoggerReplay.h"
#include "../kogger_native/navo_kogger_echogram_palette.h"
#include "../kogger_native/navo_kogger_echogram_sampling.h"
#include <QPainter>
#include <QPainterPath>
#include <QImage>
#include <QMutexLocker>
#include <QPen>
#include <QFont>
#include <QtMath>
#include <algorithm>
#include <cmath>

NavoKoggerEchogramItem::NavoKoggerEchogramItem(QQuickItem* parent)
    : QQuickPaintedItem(parent) {
    setOpaquePainting(true);
    setAntialiasing(false);
    _frameTimer.setSingleShot(true);
    _frameTimer.setInterval(33); // coalesce fast replay into <= ~30 UI updates/sec
    connect(&_frameTimer,&QTimer::timeout,this,[this](){update();});
    _fileLoadTimer.setSingleShot(true);
    _fileLoadTimer.setInterval(1);
    connect(&_fileLoadTimer,&QTimer::timeout,this,&NavoKoggerEchogramItem::loadFileBatch);
}
int NavoKoggerEchogramItem::columnCount() const {
    QMutexLocker lock(&_mutex);
    return _fileTotalColumns>0 ? _fileColumns.size() : _columns.size();
}
void NavoKoggerEchogramItem::geometryChange(const QRectF& now,const QRectF& before) {
    QQuickPaintedItem::geometryChange(now,before);
    if(now.size()!=before.size())refreshFileViewport();
}
// Kogger-style cursor: the file index belongs to the replay object, while the
// on-screen window and a bounded decoded cache belong to the renderer.
// Switching viewport never calls seekColumn(), feedBytes() or Dataset::clear().
void NavoKoggerEchogramItem::setFileReplay(QObject* source) {
    auto* next=qobject_cast<NavoKoggerReplay*>(source);
    if(_fileReplay==next)return;
    _fileLoadTimer.stop();
    if(_fileReplay)disconnect(_fileReplay,nullptr,this,nullptr);
    {
        QMutexLocker lock(&_mutex);
        _fileReplay=next;
        _fileTotalColumns=next && next->indexReady() ? next->indexedColumns() : 0;
        _fileColumns.clear();_fileCacheOrder.clear();_fileAttempted.clear();_fileCacheBytes=0;
    }
    if(next){
        connect(next,&NavoKoggerReplay::indexChanged,this,[this](){
            auto* r=qobject_cast<NavoKoggerReplay*>(_fileReplay.data());
            {
                QMutexLocker lock(&_mutex);
                _fileTotalColumns=r && r->indexReady()?r->indexedColumns():0;
            }
            refreshFileViewport();
        });
        connect(next,&QObject::destroyed,this,[this](){
            _fileReplay=nullptr;
            _fileLoadTimer.stop();
            {
                QMutexLocker lock(&_mutex);
                _fileTotalColumns=0;_fileColumns.clear();
                _fileCacheOrder.clear();_fileAttempted.clear();_fileCacheBytes=0;
            }
            emit fileReplayChanged();emit columnsChanged();requestFrame();
        });
    }
    emit fileReplayChanged();
    emit columnsChanged();
    refreshFileViewport();
}
void NavoKoggerEchogramItem::setFileWindowStart(int start) {
    start=std::max(0,start);
    if(_fileWindowStart==start)return;
    _fileWindowStart=start;emit fileViewportChanged();refreshFileViewport();
}
void NavoKoggerEchogramItem::setFileSelectedColumn(int column) {
    column=std::max(0,column);
    if(_fileSelectedColumn==column)return;
    _fileSelectedColumn=column;emit fileViewportChanged();requestFrame();
}
void NavoKoggerEchogramItem::setFileWindowColumns(int count) {
    count=std::clamp(count,1,500000);
    if(_fileWindowColumns==count)return;
    _fileWindowColumns=count;emit fileViewportChanged();refreshFileViewport();
}
int NavoKoggerEchogramItem::fileIndexAtPixel(int x,int imageWidth,int fileSize) const {
    if(fileSize<=0 || imageWidth<=0 || x<0 || x>=imageWidth)return -1;
    const int span=std::clamp(_fileWindowColumns,1,fileSize);
    const int start=std::clamp(_fileWindowStart,0,fileSize-span);
    // Pixel centres sample the entire recording at full-file zoom, with
    // exact per-column access after zoom-in; no artificial 4096-column cap.
    return start+int((qint64(2)*x+1)*span/(qint64(2)*imageWidth));
}
void NavoKoggerEchogramItem::refreshFileViewport() {
    _fileAttempted.clear();
    auto* r=qobject_cast<NavoKoggerReplay*>(_fileReplay.data());
    if(r && r->indexReady() && _fileTotalColumns>0 && width()>0){
        _fileLoadTimer.start();
    }
    requestFrame();
}
void NavoKoggerEchogramItem::loadFileBatch() {
    auto* r=qobject_cast<NavoKoggerReplay*>(_fileReplay.data());
    if(!r || !r->indexReady() || _fileTotalColumns<=0 || width()<=0)return;
    const int imageW=std::clamp(int(std::ceil(width())),1,2048);
    int loaded=0;bool pending=false;
    for(int px=0;px<imageW;++px) {
        const int idx=fileIndexAtPixel(px,imageW,_fileTotalColumns);
        if(idx<0)continue;
        {
            QMutexLocker lock(&_mutex);
            if(_fileColumns.contains(idx)||_fileAttempted.contains(idx))continue;
        }
        if(loaded>=12){pending=true;break;}
        NavoKoggerReplay::ChartColumn source;
        const bool ok=r->readChartColumn(idx,&source);
        Column c;
        if(ok) {
            c.bytes=std::move(source.bytes);
            c.resolutionMm=source.resolutionMm;
            c.absoluteOffset=source.absoluteOffset;
            c.version=source.version;
        }
        // Cache even unreadable columns as empty so corrupt data cannot
        // restart an infinite read loop. Empty pixels remain transparent/black.
        {
            QMutexLocker lock(&_mutex);
            _fileCacheBytes+=c.bytes.size();
            _fileColumns.insert(idx,std::move(c));
            _fileCacheOrder.enqueue(idx);
            while(_fileCacheOrder.size()>MaxFileCacheColumns ||
                  _fileCacheBytes>MaxFileCacheBytes) {
                const int oldest=_fileCacheOrder.dequeue();
                auto it=_fileColumns.find(oldest);
                if(it!=_fileColumns.end()) {
                    _fileCacheBytes-=it.value().bytes.size();
                    _fileColumns.erase(it);
                }
            }
        }
        _fileAttempted.insert(idx);
        ++loaded;
    }
    if(loaded){emit columnsChanged();requestFrame();}
    if(pending)_fileLoadTimer.start();
}

void NavoKoggerEchogramItem::requestFrame() {
    if(!_frameTimer.isActive())_frameTimer.start();
}
void NavoKoggerEchogramItem::setDecoder(QObject* source) {
    auto* next=qobject_cast<NavoKoggerDecoder*>(source);
    if (_decoder==next)return;
    if (_decoder)disconnect(_decoder,nullptr,this,nullptr);
    _decoder=next;
    resetColumns();
    if(_decoder) {
        connect(_decoder,&NavoKoggerDecoder::chartColumnReady,
                this,&NavoKoggerEchogramItem::receiveColumn);
        connect(_decoder,&QObject::destroyed,this,[this](){
            _decoder=nullptr;resetColumns();emit decoderChanged();
        });
    }
    emit decoderChanged();
}
void NavoKoggerEchogramItem::receiveColumn() {
    if(_frozen || !_decoder)return;
    Column c;
    c.bytes=_decoder->chartRawBytes();
    c.sequence=_decoder->chartSequence();
    c.resolutionMm=_decoder->chartResolution();
    c.absoluteOffset=_decoder->chartAbsoluteOffset();
    c.version=_decoder->chartVersion();
    if(c.bytes.isEmpty() || c.bytes.size()>128*1024 ||
       c.resolutionMm==0 || c.version>1)return;
    {
        QMutexLocker lock(&_mutex);
        _rawCacheBytes+=c.bytes.size();
        _columns.append(std::move(c));
        while(_columns.size()>MaxRetainedColumns || _rawCacheBytes>MaxRawCacheBytes) {
            _rawCacheBytes-=_columns.first().bytes.size();
            _columns.removeFirst();
        }
    }
    emit columnsChanged();
    requestFrame();
}
void NavoKoggerEchogramItem::resetColumns() {
    {
        QMutexLocker lock(&_mutex);
        _columns.clear();
        _rawCacheBytes=0;
    }
    emit columnsChanged();
    requestFrame();
}
void NavoKoggerEchogramItem::setBottomDepth(quint64 sequence, double depth) {
    if(!std::isfinite(depth) || depth<=0 || depth>1000)return;
    bool changed=false;
    {
        QMutexLocker lock(&_mutex);
        for(auto it=_columns.rbegin();it!=_columns.rend();++it) {
            if(it->sequence==sequence) {it->bottom=depth;changed=true;break;}
        }
    }
    if(changed)requestFrame();
}
void NavoKoggerEchogramItem::setDepthFrom(qreal v) {
    if(!std::isfinite(v)||v<0||qFuzzyCompare(_from+1,v+1))return;
    _from=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setDepthRange(qreal v) {
    if(!std::isfinite(v)||v<=0||v>1000||qFuzzyCompare(_range,v))return;
    _range=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setPaletteMode(int v) {
    if(v<0||v>2||v==_palette)return;
    _palette=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setLowLevel(qreal v) {
    v=std::clamp(v,0.0,99.0);
    if(qFuzzyCompare(_low+1,v+1))return;
    _low=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setHighLevel(qreal v) {
    v=std::clamp(v,1.0,100.0);
    if(qFuzzyCompare(_high,v))return;
    _high=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setGain(qreal v) {
    if(!std::isfinite(v)||v<=0||v>8||qFuzzyCompare(_gain,v))return;
    _gain=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setNoiseFloor(qreal v) {
    if(!std::isfinite(v))return;
    v=std::clamp(v,0.0,0.95);
    if(qFuzzyCompare(_noiseFloor+1,v+1))return;
    _noiseFloor=v;emit displayChanged();requestFrame();
}
void NavoKoggerEchogramItem::setFrozen(bool v) {
    if(_frozen==v)return;
    _frozen=v;emit frozenChanged();
}
void NavoKoggerEchogramItem::setShowBottomTrack(bool v) {
    if(_showBottom==v)return;
    _showBottom=v;emit displayChanged();requestFrame();
}
QVariantMap NavoKoggerEchogramItem::inspectAt(qreal x,qreal y) const {
    if(width()<=0 || height()<=0 || x<0 || y<0 || x>=width() || y>=height())return {};
    const int imageW=std::clamp(int(std::ceil(width())),1,2048);
    const int pos=std::clamp(int(x*imageW/width()),0,imageW-1);
    const double selectedDepth=_from+y/height()*_range;
    Column c;
    int epoch=-1;
    {
        QMutexLocker lock(&_mutex);
        if(_fileTotalColumns>0){
            epoch=fileIndexAtPixel(pos,imageW,_fileTotalColumns);
            if(!_fileColumns.contains(epoch))return {};
            c=_fileColumns.value(epoch);
        }else{
            epoch=_columns.size()-imageW+pos;
            if(epoch<0||epoch>=_columns.size())return {};
            c=_columns[epoch];
        }
        if(c.bytes.isEmpty()||c.resolutionMm==0)return {};
    }
    const double resolution=c.resolutionMm*0.001;
    const double offset=c.absoluteOffset*resolution;
    const double pixelDepth=_range/qMax(1.0,height());
    const quint8 signal=NavoKoggerSampling::atDisplayDepth(
        c.bytes,c.version,offset,resolution,selectedDepth,pixelDepth);
    return QVariantMap{
        {"column",epoch+1},{"sequence",_fileTotalColumns>0?QVariant():QVariant::fromValue(c.sequence)},
        {"selectedDepthM",selectedDepth},{"bottomDepthM",c.bottom},
        {"amplitudePercent",100.0*double(signal)/255.0},
        {"resolutionMm",c.resolutionMm},{"sourceOffsetM",offset},
        {"sampleCount",c.bytes.size()/(c.version==1?2:1)},
        {"source",_fileTotalColumns>0?QStringLiteral("Kogger KLF on-disk CHART 8-bit"):QStringLiteral("Kogger CHART 8-bit")}
    };
}
void NavoKoggerEchogramItem::paint(QPainter* p) {
    if(!p || width()<=0 || height()<=0)return;
    const int imageW=std::clamp(int(std::ceil(width())),1,2048);
    const int imageH=std::clamp(int(std::ceil(height())),1,1600);
    const double from=_from, range=_range;
    QVector<Column> visible;
    int fileTotal=0;
    {
        QMutexLocker lock(&_mutex);
        fileTotal=_fileTotalColumns;
        if(fileTotal>0){
            visible.reserve(imageW);
            for(int x=0;x<imageW;++x){
                const int index=fileIndexAtPixel(x,imageW,_fileTotalColumns);
                visible.append(_fileColumns.value(index));
            }
        }else{
            const int start=std::max(0,int(_columns.size())-imageW);
            visible=_columns.mid(start);
        }
    }
    QImage image(imageW,imageH,QImage::Format_Indexed8);
    image.setColorTable(NavoKoggerPalette::colors(_palette,float(_low),float(_high)));
    image.fill(0);
    // Same per-screen-pixel column caching approach as Kogger Plot2DEchogram.
    // No JS sample conversion and no four-bin quantisation.
    for(int i=0;i<visible.size();++i) {
        const int x=imageW-visible.size()+i;
        const auto& col=visible[i];
        if(col.bytes.isEmpty() || col.resolutionMm==0)continue;
        const double resolution=col.resolutionMm*0.001;
        const double offset=col.absoluteOffset*resolution;
        for(int y=0;y<imageH;++y) {
            const double depth=from+(double(y)+0.5)*range/double(imageH);
            const auto raw=NavoKoggerSampling::atDisplayDepth(
                col.bytes,col.version,offset,resolution,depth,range/double(imageH));
            const int value=std::clamp(qRound((double(raw)/255.0-_noiseFloor)*_gain*255.0),0,255);
            image.scanLine(y)[x]=quint8(value);
        }
    }
    p->drawImage(QRectF(0,0,width(),height()),image);
    // Native bottom is metadata, not a synthetic bright band in the CHART.
    if(_showBottom && range>0 && !visible.isEmpty()) {
        QPainterPath line;
        bool started=false;
        for(int i=0;i<visible.size();++i) {
            const auto& col=visible[i];
            if(!std::isfinite(col.bottom)) {started=false;continue;}
            const double depthY=(col.bottom-from)/range*height();
            if(depthY<0||depthY>height()) {started=false;continue;}
            const qreal px=(imageW-visible.size()+i+0.5)*width()/imageW;
            if(started)line.lineTo(px,depthY);
            else {line.moveTo(px,depthY);started=true;}
        }
        p->setPen(QPen(QColor("#ffda67"),1.0));
        p->setRenderHint(QPainter::Antialiasing,true);
        p->drawPath(line);
        p->setRenderHint(QPainter::Antialiasing,false);
    }
    // Cursor is a position in the complete KLF index, not replay progress.
    if(fileTotal>0){
        const int span=std::clamp(_fileWindowColumns,1,fileTotal);
        const int start=std::clamp(_fileWindowStart,0,fileTotal-span);
        if(_fileSelectedColumn>=start && _fileSelectedColumn<start+span){
            const qreal x=(qreal(_fileSelectedColumn-start)+0.5)*width()/span;
            p->setPen(QPen(QColor(255,207,76,205),1.5));
            p->drawLine(QPointF(x,0),QPointF(x,height()));
        }
    }
    p->setFont(QFont(QStringLiteral("Sans Serif"),10));
    for(int i=0;i<=4;++i) {
        const qreal y=i*height()/4;
        p->setPen(QPen(QColor(80,140,175,95),1));
        p->drawLine(QPointF(0,y),QPointF(width(),y));
        const QString text=QString::number(from+i*range/4,'f',1)+QStringLiteral(" m");
        const qreal labelY=std::clamp(y+15.0,15.0,qMax(15.0,height()-3.0));
        const QRectF r(5,labelY-14,65,17);
        p->fillRect(r,QColor(3,14,24,210));
        p->setPen(QColor("#d9edf7"));
        p->drawText(r.adjusted(5,0,-2,0),Qt::AlignLeft|Qt::AlignVCenter,text);
    }
}
