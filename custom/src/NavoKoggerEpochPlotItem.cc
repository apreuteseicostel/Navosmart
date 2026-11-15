// KoggerApp native Epoch::chartTo sampling, and colour stops transcribed
// from KoggerApp/src/scene2d/plot2D_echogram.cpp (GPL-3.0).
// The actual KoggerApp Core/main/qPlot2D classes are NOT duplicated.
#include "NavoKoggerEpochPlotItem.h"
#include "../kogger_native/NavoKoggerService.h"
#include "../../third_party/KoggerApp/src/epoch.h"
#include <QPainter>
#include <QMutexLocker>
#include <QImage>
#include <QElapsedTimer>
#include <QFont>
#include <QColor>
#include <QTimer>
#include <QMetaObject>
#include <QtMath>
#include <algorithm>
#include <cmath>

NavoKoggerEpochPlotItem::NavoKoggerEpochPlotItem(QQuickItem* parent)
    :QQuickPaintedItem(parent),_sourceUuid(QUuid::createUuid()){
    setOpaquePainting(true);
    _loadTimer.setInterval(1);_loadTimer.setSingleShot(true);
    connect(&_loadTimer,&QTimer::timeout,this,&NavoKoggerEpochPlotItem::loadVisibleBatch);
    _refreshTimer.setInterval(100);
    connect(&_refreshTimer,&QTimer::timeout,this,[this](){
        if(!isVisible())return;
        if(fileReady())return; // File view is updated only when data/position changes.
        emit dataChanged();update();
    });
    _refreshTimer.start();
    connect(&NavoKoggerService::instance(),&NavoKoggerService::processingChanged,
            this,[this](){if(!_file&&isVisible()){emit dataChanged();update();}});
}
void NavoKoggerEpochPlotItem::geometryChange(const QRectF& next,const QRectF& old){
    QQuickPaintedItem::geometryChange(next,old);
    // Raster rows depend on physical view height. Width-only changes may reuse them.
    if(next.height()!=old.height())clearFileCache();
    if(next.size()!=old.size())queueVisible();
}
void NavoKoggerEpochPlotItem::clearFileCache(){
    _loadTimer.stop();
    QMutexLocker lock(&_cacheMutex);
    _cache.clear();_order.clear();_cachedBytes=0;_lastCompleteFrame=QImage();
}
void NavoKoggerEpochPlotItem::setFileReplay(QObject* source){
    auto* value=qobject_cast<NavoKoggerReplay*>(source);
    if(value==_file)return;
    if(_file)disconnect(_file,nullptr,this,nullptr);
    _file=value;clearFileCache();
    if(_file){
        connect(_file,&NavoKoggerReplay::indexChanged,this,[this](){
            clearFileCache();emit dataChanged();queueVisible();
        });
        connect(_file,&QObject::destroyed,this,[this](){
            _file=nullptr;clearFileCache();emit fileReplayChanged();emit dataChanged();update();
        });
    }
    emit fileReplayChanged();emit dataChanged();queueVisible();
}
int NavoKoggerEpochPlotItem::indexedColumns() const{
    // Never reinterpret a not-yet-indexed KLF as a live Dataset.
    if(_file)return _file->indexedColumns();
    return NavoKoggerService::instance().dataset().sizeThreadSafe();
}
bool NavoKoggerEpochPlotItem::fileReady() const{return _file&&_file->indexReady()&&_file->indexedColumns()>0;}
void NavoKoggerEpochPlotItem::setPosition(double v){
    if(!std::isfinite(v))return;v=std::clamp(v,0.0,1.0);
    if(qFuzzyCompare(_position+1,v+1))return;
    _position=v;emit viewChanged();queueVisible();
}
void NavoKoggerEpochPlotItem::setHorizontalZoom(int z){
    z=std::clamp(z,1,64);if(_zoom==z)return;
    _zoom=z;emit viewChanged();queueVisible();
}
void NavoKoggerEpochPlotItem::setDepthFrom(double v){
    if(!std::isfinite(v)||v<0||qFuzzyCompare(_from+1,v+1))return;
    _from=v;clearFileCache();emit viewChanged();queueVisible();
}
void NavoKoggerEpochPlotItem::setDepthRange(double v){
    if(!std::isfinite(v)||v<=0||v>500||qFuzzyCompare(_range,v))return;
    _range=v;clearFileCache();emit viewChanged();queueVisible();
}
void NavoKoggerEpochPlotItem::setPalette(int v){
    v=std::clamp(v,0,2);if(_palette==v)return;
    _palette=v;emit viewChanged();update();
}
void NavoKoggerEpochPlotItem::setLevelLow(double v){
    v=std::clamp(v,0.0,99.0);if(qFuzzyCompare(_low+1,v+1))return;
    _low=v;emit viewChanged();update();
}
void NavoKoggerEpochPlotItem::setLevelHigh(double v){
    v=std::clamp(v,1.0,100.0);if(qFuzzyCompare(_high+1,v+1))return;
    _high=v;emit viewChanged();update();
}
void NavoKoggerEpochPlotItem::setCompensate(bool v){
    if(_compensate==v)return;
    _compensate=v;clearFileCache();emit viewChanged();queueVisible();
}
int NavoKoggerEpochPlotItem::sourceColumn(int x,int n,int w) const{
    if(n<=0||w<=0||x<0||x>=w)return -1;
    const int count=std::clamp(int(std::ceil(double(n)/double(_zoom))),1,n);
    const int center=std::clamp(int(std::round(_position*double(n-1))),0,n-1);
    const int start=std::clamp(center-count/2,0,n-count);
    return std::clamp(start+int((qint64(2)*x+1)*count/(qint64(2)*w)),0,n-1);
}
void NavoKoggerEpochPlotItem::queueVisible(){
    if(fileReady()&&width()>0) _loadTimer.start();
    update();
}
void NavoKoggerEpochPlotItem::loadVisibleBatch(){
    if(!fileReady()||!isVisible()||height()<=0)return;
    const int n=_file->indexedColumns();
    const int w=std::clamp(int(std::ceil(width())),1,2048);
    const int h=std::clamp(int(std::ceil(height())),1,1200);
    const ChannelId fileChannel(_sourceUuid,1);
    int added=0;
    bool pending=false;
    int previousColumn=-1;
    QElapsedTimer budget;
    budget.start();
    for(int x=0;x<w;++x){
        const int idx=sourceColumn(x,n,w);
        if(idx<0||idx==previousColumn)continue;
        previousColumn=idx;
        {QMutexLocker lock(&_cacheMutex);if(_cache.contains(idx))continue;}
        // Avoid a long GUI-thread stall, but load more than twelve columns
        // per event on a fast phone. Resume from the visible cache next tick.
        if(added>=96||(added>=8&&budget.elapsed()>=7)){pending=true;break;}
        FileColumn c;
        NavoKoggerReplay::ChartColumn raw;
        if(_file->readChartColumn(idx,&raw)&&raw.resolutionMm>0&&raw.version<=1){
            // The decoder accepts both Kogger CHART v0 and v1. v1 stores
            // two bytes per amplitude sample; the existing decoder uses
            // the first byte of each pair. Mirror that here or v1 columns
            // become permanent gaps in the native viewport.
            const int step=raw.version==1?2:1;
            QVector<uint8_t> samples;
            samples.reserve((raw.bytes.size()+step-1)/step);
            for(qsizetype i=0;i+step-1<raw.bytes.size();i+=step)
                samples.append(quint8(raw.bytes.at(i)));
            if(!samples.isEmpty()){
                Epoch epoch;
                epoch.setChart(fileChannel,{samples},float(raw.resolutionMm)*.001f,
                               float(raw.absoluteOffset)*float(raw.resolutionMm)*.001f);
                QVector<int16_t> scan(h);
                if(epoch.chartTo(fileChannel,0,float(_from),float(_from+_range),
                                 scan.data(),h,_compensate?1:0)){
                    c.raster.resize(h);
                    for(int y=0;y<h;++y)
                        c.raster[y]=char(std::clamp(int(scan[y]),0,255));
                }
            }
        }
        {
            QMutexLocker lock(&_cacheMutex);
            _cachedBytes+=c.raster.size();
            _cache.insert(idx,std::move(c));
            _order.enqueue(idx);
            while(_order.size()>MaxEntries||_cachedBytes>MaxBytes){
                const int discard=_order.dequeue();
                auto it=_cache.find(discard);
                if(it!=_cache.end()){
                    _cachedBytes-=it.value().raster.size();
                    _cache.erase(it);
                }
            }
        }
        ++added;
    }
    // Publish the *whole* requested view, not a fresh picture after every
    // 8–96-column batch. Showing incomplete buffers caused the visible
    // vertical stripes in the fast-scrolling Android recordings.
    if(added&&!pending)update();
    // Do not stop loading when cache reaches its bound: each newly visible
    // column evicts an old one. The previous capacity gate caused black strips
    // after panning through a large KLF (stale offscreen entries filled the cache).
    if(pending)_loadTimer.start();
}
QVector<QRgb> NavoKoggerEpochPlotItem::colors() const{
    // Original KoggerApp Plot2DEchogram Classic, Ice, Sepia colour stops.
    QVector<QColor> colors;
    QVector<int> stops;
    if(_palette==1){
        colors={QColor(0,0,70),QColor(0,40,150),QColor(0,100,230),
                QColor(0,180,255),QColor(0,240,255),QColor(80,255,230),
                QColor(170,255,255),QColor(230,255,255),QColor(255,255,255)};
        stops={0,30,60,95,130,170,210,235,255};
    }else if(_palette==2){
        colors={QColor(0,0,0),QColor(50,50,10),QColor(230,200,100),QColor(255,255,220)};
        stops={0,30,130,255};
    }else{
        colors={QColor(0,0,0),QColor(20,5,80),QColor(50,180,230),
                QColor(190,240,250),QColor(255,255,255)};
        stops={0,30,130,220,255};
    }
    QVector<QRgb> lut(256,qRgb(0,0,0));
    for(int i=0;i<colors.size()-1;++i){
        for(int p=stops[i];p<=stops[i+1];++p){
            const double t=double(p-stops[i])/std::max(1,stops[i+1]-stops[i]);
            lut[p]=qRgb(qRound(colors[i].red()*(1-t)+colors[i+1].red()*t),
                         qRound(colors[i].green()*(1-t)+colors[i+1].green()*t),
                         qRound(colors[i].blue()*(1-t)+colors[i+1].blue()*t));
        }
    }
    QVector<QRgb> mapped(256);
    const double scale=_high>_low ? 255.0/((_high-_low)*2.55) : 10000.0;
    const int shift=int(_low*2.5);
    for(int i=0;i<256;++i)mapped[i]=lut[std::clamp(int((i-shift)*scale),0,255)];
    return mapped;
}
QVariantMap NavoKoggerEpochPlotItem::inspectAt(double x,double y) const{
    if(width()<=0||height()<=0||x<0||x>=width()||y<0||y>=height())return {};
    const int n=indexedColumns(),w=std::clamp(int(std::ceil(width())),1,2048);
    const int idx=sourceColumn(std::clamp(int(x*w/width()),0,w-1),n,w);
    if(idx<0)return {};
    if(_file && !fileReady())return {};
    return QVariantMap{{"epoch",idx+1},{"depthM",_from+y/height()*_range},
                       {"indexedColumns",n},{"source",fileReady()?"KLF Indexed":"Kogger Dataset live"}};
}
void NavoKoggerEpochPlotItem::paint(QPainter* p){
    if(!p||width()<=0||height()<=0)return;
    const int w=std::clamp(int(std::ceil(width())),1,2048);
    const int h=std::clamp(int(std::ceil(height())),1,1200);
    QImage image(w,h,QImage::Format_Indexed8);
    image.setColorTable(colors());
    image.fill(0);

    // Explicit loading/error state prevents KLF mode from leaking stale
    // live Dataset epochs while a file is being indexed or has no CHART.
    if(_file&&!fileReady()){
        p->fillRect(boundingRect(),QColor("#050d17"));
        p->setPen(QColor("#9dc7dd"));
        p->drawText(boundingRect(),Qt::AlignCenter,
                    _file->indexReady()?QStringLiteral("KLF fără coloane CHART valide")
                                      :QStringLiteral("Indexare fișier KLF…"));
        return;
    }

    const int n=indexedColumns();
    const bool onFile=bool(_file);
    int invalidColumns=0;
    if(onFile){
        // CHART is decoded in bounded batches outside paint. Do not publish
        // half-loaded viewports (the stripes/black frames in videos 33088/33091).
        int waitingColumns=0;
        {
            QMutexLocker lock(&_cacheMutex);
            int previousColumn=-1;
            for(int x=0;x<w;++x){
                const int idx=sourceColumn(x,n,w);
                if(idx<0)continue;
                const auto it=_cache.constFind(idx);
                if(it==_cache.cend()){
                    if(idx!=previousColumn)++waitingColumns;
                    previousColumn=idx;
                    continue;
                }
                if(it.value().raster.size()!=h){
                    if(idx!=previousColumn)++invalidColumns;
                    previousColumn=idx;
                    continue;
                }
                previousColumn=idx;
                const QByteArray& column=it.value().raster;
                for(int y=0;y<h;++y)
                    image.scanLine(y)[x]=quint8(column.at(y));
            }
            if(!waitingColumns)_lastCompleteFrame=image;
        }
        if(waitingColumns){
            // Previous viewport is explicitly dimmed and marked as loading;
            // never pretend that old CHART data belongs to the new position.
            p->fillRect(boundingRect(),QColor("#050d17"));
            if(!_lastCompleteFrame.isNull()&&_lastCompleteFrame.size()==image.size()){
                QImage previous=_lastCompleteFrame;
                previous.setColorTable(colors());
                p->drawImage(QRectF(0,0,width(),height()),previous);
                p->fillRect(boundingRect(),QColor(0,0,0,135));
            }
            p->setPen(QColor("#e8f4fc"));
            p->drawText(boundingRect(),Qt::AlignCenter,
                        QStringLiteral("Se încarcă %1 coloane CHART…").arg(waitingColumns));
            return;
        }
    }else{
        Dataset* dataset=&NavoKoggerService::instance().dataset();
        QVector<int16_t> scan(h);
        for(int x=0;x<w;++x){
            const int idx=sourceColumn(x,n,w);
            if(idx<0)continue;
            Epoch epoch=dataset->fromIndexCopy(idx);
            const auto channels=epoch.chartChannels();
            if(channels.isEmpty())continue;
            if(!epoch.chartTo(channels.first(),0,float(_from),float(_from+_range),
                              scan.data(),h,_compensate?1:0))continue;
            for(int y=0;y<h;++y)
                image.scanLine(y)[x]=quint8(std::clamp(int(scan[y]),0,255));
        }
    }
    p->drawImage(QRectF(0,0,width(),height()),image);
    if(invalidColumns>0){
        p->setPen(QColor("#ffba80"));
        p->drawText(QPointF(10,std::max(24.0,height()-14.0)),
                    QStringLiteral("CHART invalide: %1").arg(invalidColumns));
    }
    p->setPen(QColor("#a9d5ea"));
    for(int i=0;i<=4;++i){
        const double depth=_from+i*_range/4;
        const double yy=i*height()/4;
        p->drawLine(QPointF(0,yy),QPointF(width(),yy));
        p->drawText(QPointF(5,std::clamp(yy+14.0,14.0,height()-4)),
                    QString::number(depth,'f',1)+" m");
    }
}
