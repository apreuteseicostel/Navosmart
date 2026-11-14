#include "NavoKoggerEchogramItem.h"
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
}
int NavoKoggerEchogramItem::columnCount() const {
    QMutexLocker lock(&_mutex);
    return _columns.size();
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
        epoch=_columns.size()-imageW+pos;
        if(epoch<0||epoch>=_columns.size())return {};
        c=_columns[epoch];
    }
    const double resolution=c.resolutionMm*0.001;
    const double offset=c.absoluteOffset*resolution;
    const double pixelDepth=_range/qMax(1.0,height());
    const quint8 signal=NavoKoggerSampling::atDisplayDepth(
        c.bytes,c.version,offset,resolution,selectedDepth,pixelDepth);
    return QVariantMap{
        {"column",epoch+1},{"sequence",QVariant::fromValue(c.sequence)},
        {"selectedDepthM",selectedDepth},{"bottomDepthM",c.bottom},
        {"amplitudePercent",100.0*double(signal)/255.0},
        {"resolutionMm",c.resolutionMm},{"sourceOffsetM",offset},
        {"sampleCount",c.bytes.size()/(c.version==1?2:1)},
        {"source",QStringLiteral("Kogger CHART 8-bit")}
    };
}
void NavoKoggerEchogramItem::paint(QPainter* p) {
    if(!p || width()<=0 || height()<=0)return;
    const int imageW=std::clamp(int(std::ceil(width())),1,2048);
    const int imageH=std::clamp(int(std::ceil(height())),1,1600);
    const double from=_from, range=_range;
    QVector<Column> visible;
    {
        QMutexLocker lock(&_mutex);
        const int start=std::max(0,int(_columns.size())-imageW);
        visible=_columns.mid(start);
    }
    QImage image(imageW,imageH,QImage::Format_Indexed8);
    image.setColorTable(NavoKoggerPalette::colors(_palette,float(_low),float(_high)));
    image.fill(0);
    // Same per-screen-pixel column caching approach as Kogger Plot2DEchogram.
    // No JS sample conversion and no four-bin quantisation.
    for(int i=0;i<visible.size();++i) {
        const int x=imageW-visible.size()+i;
        const auto& col=visible[i];
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
