// KoggerApp native Epoch::chartTo sampling, and colour stops transcribed
// from KoggerApp/src/scene2d/plot2D_echogram.cpp (GPL-3.0).
// The actual KoggerApp Core/main/qPlot2D classes are NOT duplicated.
#include "NavoKoggerEpochPlotItem.h"
#include "../kogger_native/NavoKoggerService.h"
#include "../../third_party/KoggerApp/src/epoch.h"
#include <QPainter>
#include <QMutexLocker>
#include <QImage>
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
            this,[this](){if(!fileReady()&&isVisible()){emit dataChanged();update();}});
}
void NavoKoggerEpochPlotItem::geometryChange(const QRectF& next,const QRectF& old){
    QQuickPaintedItem::geometryChange(next,old);
    if(next.size()!=old.size())queueVisible();
}
void NavoKoggerEpochPlotItem::clearFileCache(){
    _loadTimer.stop();
    QMutexLocker lock(&_cacheMutex);
    _cache.clear();_order.clear();_cachedBytes=0;
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
    if(fileReady())return _file->indexedColumns();
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
    _from=v;emit viewChanged();update();
}
void NavoKoggerEpochPlotItem::setDepthRange(double v){
    if(!std::isfinite(v)||v<=0||v>500||qFuzzyCompare(_range,v))return;
    _range=v;emit viewChanged();update();
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
    _compensate=v;emit viewChanged();update();
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
    if(!fileReady()||!isVisible())return;
    const int n=_file->indexedColumns();
    const int w=std::clamp(int(std::ceil(width())),1,2048);
    int added=0;bool pending=false;
    for(int x=0;x<w;++x){
        const int idx=sourceColumn(x,n,w);
        if(idx<0)continue;
        {QMutexLocker lock(&_cacheMutex);if(_cache.contains(idx))continue;}
        if(added>=12){pending=true;break;}
        NavoKoggerReplay::ChartColumn raw;
        FileColumn c;
        if(_file->readChartColumn(idx,&raw)){
            c.bytes=raw.bytes;c.resolution=raw.resolutionMm;
            c.offset=raw.absoluteOffset;c.version=raw.version;
        }
        {
            QMutexLocker lock(&_cacheMutex);
            _cachedBytes+=c.bytes.size();
            _cache.insert(idx,std::move(c));_order.enqueue(idx);
            while(_order.size()>MaxEntries||_cachedBytes>MaxBytes){
                const int discard=_order.dequeue();
                auto it=_cache.find(discard);
                if(it!=_cache.end()){
                    _cachedBytes-=it.value().bytes.size();
                    _cache.erase(it);
                }
            }
        }
        ++added;
    }
    if(added)update();
    // Bounded cache: do not loop forever if the visible set is larger than the budget.
    bool canContinue=false;
    {QMutexLocker lock(&_cacheMutex);
        canContinue=_cache.size()<MaxEntries && _cachedBytes<MaxBytes;
    }
    if(pending && canContinue)_loadTimer.start();
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
    return QVariantMap{{"epoch",idx+1},{"depthM",_from+y/height()*_range},
                       {"indexedColumns",n},{"source",fileReady()?"KLF Indexed":"Kogger Dataset live"}};
}
void NavoKoggerEpochPlotItem::paint(QPainter* p){
    if(!p||width()<=0||height()<=0)return;
    const int w=std::clamp(int(std::ceil(width())),1,2048);
    const int h=std::clamp(int(std::ceil(height())),1,1200);
    QImage image(w,h,QImage::Format_Indexed8);
    image.setColorTable(colors());image.fill(0);
    const int n=indexedColumns();
    const bool onFile=fileReady();
    Dataset* dataset=onFile?nullptr:&NavoKoggerService::instance().dataset();
    const ChannelId fileChannel(_sourceUuid,1);
    QVector<int16_t> scan(h);
    for(int x=0;x<w;++x){
        const int idx=sourceColumn(x,n,w);
        if(idx<0)continue;
        Epoch epoch;
        ChannelId channel;
        if(onFile){
            FileColumn c;
            {
                QMutexLocker lock(&_cacheMutex);
                const auto it=_cache.constFind(idx);
                if(it==_cache.cend())continue;
                c=it.value(); // implicit-shared QByteArray snapshot
            }
            if(c.resolution==0||c.version!=0)continue;
            QVector<uint8_t> samples;
            samples.reserve(c.bytes.size());
            for(const auto b:c.bytes)samples.append(quint8(b));
            epoch.setChart(fileChannel,{samples},float(c.resolution)*.001f,
                           float(c.offset)*float(c.resolution)*.001f);
            channel=fileChannel;
        }else{
            epoch=dataset->fromIndexCopy(idx);
            const auto channels=epoch.chartChannels();
            if(channels.isEmpty())continue;
            channel=channels.first();
        }
        // This is the unmodified upstream Kogger Epoch::chartTo raster sampler,
        // not the old NAVO four-bin Canvas algorithm.
        if(!epoch.chartTo(channel,0,float(_from),float(_from+_range),scan.data(),h,
                          _compensate?1:0))continue;
        for(int y=0;y<h;++y)
            image.scanLine(y)[x]=quint8(std::clamp(int(scan[y]),0,255));
    }
    p->drawImage(QRectF(0,0,width(),height()),image);
    p->setPen(QColor("#a9d5ea"));
    for(int i=0;i<=4;++i){
        const double depth=_from+i*_range/4;
        const double yy=i*height()/4;
        p->drawLine(QPointF(0,yy),QPointF(width(),yy));
        p->drawText(QPointF(5,std::clamp(yy+14.0,14.0,height()-4)),QString::number(depth,'f',1)+" m");
    }
}
