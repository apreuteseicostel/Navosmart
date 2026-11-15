#pragma once
#include <QByteArray>
#include <QVector>
#include <QtGlobal>
#include <algorithm>
#include <cmath>

// Experimental C: full-column port of upstream KoggerApp Epoch::chartTo
// (src/epoch.h, GPL-3.0). The current NAVO renderer samples each display
// pixel separately; Kogger's native rasteriser instead creates an entire
// column using its scaleFactor/average/interpolation rules.
// Copyright remains with the upstream KoggerApp authors; see
// third_party/KoggerApp/LICENSE. This is a view-only conversion.
// v1 raw CHART is intentionally not passed into the unverified v0 algorithm.
namespace NavoKoggerOriginalRaster {
inline QByteArray column(const QByteArray& samples, int version,
                         double resolutionM, double offsetM,
                         double depthFrom, double depthSpan,
                         int height, bool compensate=false) {
    if(version!=0 || samples.isEmpty() || samples.size()>128*1024 ||
       !(resolutionM>0) || !(depthSpan>0) || height<1 || height>1600 ||
       !std::isfinite(resolutionM) || !std::isfinite(offsetM) ||
       !std::isfinite(depthFrom)) return {};
    const int rawSize=samples.size();
    const float resolution=float(resolutionM);
    QVector<quint8> adjusted;
    const quint8* src=reinterpret_cast<const quint8*>(samples.constData());
    if(compensate){
        adjusted.resize(rawSize);
        float average=255.0f;
        // Upstream Epoch::Echogram::compensateInPlace formula.
        for(int i=0;i<rawSize;++i){
            float val=float(src[i]);
            average+=(val-average)*(0.05f+average*0.0006f);
            val=(val-average*0.55f)*(0.85f+float(i)*resolution*0.006f)*2.0f;
            adjusted[i]=quint8(std::clamp(val,0.0f,255.0f));
        }
        src=adjusted.constData();
    }
    const float rawRange=float(rawSize)*resolution;
    const float start=float(depthFrom-offsetM);
    const float targetRange=float(depthSpan);
    const float scaleFactor=(float(rawSize)/float(height))*(targetRange/rawRange);
    const int offset=int(start/resolution); // Kogger uses truncation toward zero.
    if(!(scaleFactor>0)||!std::isfinite(scaleFactor))return {};
    QByteArray pixels(height,char(0));
    if(scaleFactor>=0.8f){
        int srcStart=offset;
        for(int y=0;y<height;++y){
            int srcEnd=int(float(y+1)*scaleFactor+float(offset));
            qint32 val=0;
            if(srcStart>=0 && srcStart<rawSize){
                srcEnd=std::min(srcEnd,rawSize);
                val=src[srcStart];
                for(int i=srcStart;i<srcEnd;++i)val+=src[i];
                val/=1+(srcEnd-srcStart);
            }
            srcStart=srcEnd;
            pixels[y]=char(quint8(std::clamp(val,qint32(0),qint32(255))));
        }
    }else{
        for(int y=0;y<height;++y){
            const float cellOffset=float(y)*scaleFactor+float(offset)+0.5f;
            const int left=int(cellOffset);
            int right=left+1;
            qint32 val=0;
            if(left>=0 && left<rawSize){
                right=std::min(right,rawSize-1);
                const float coef=cellOffset-std::floor(cellOffset);
                val=qint32(float(src[left])*(1-coef)+float(src[right])*coef);
            }
            pixels[y]=char(quint8(std::clamp(val,qint32(0),qint32(255))));
        }
    }
    return pixels;
}
} // namespace NavoKoggerOriginalRaster
