#pragma once
#include <QByteArray>
#include <QtGlobal>
#include <algorithm>
#include <cmath>

// Sampling strategy adapted from KoggerApp's original Epoch::chartTo:
// average when reducing vertical resolution; linearly interpolate when
// increasing it. Original source: src/epoch.h (GPL-3.0).
// This is *display* sampling only; CHART recordings remain unmodified.
namespace NavoKoggerSampling {
inline quint8 at(const QByteArray& samples, int sample, int step) {
    if (sample < 0 || step < 1 || sample >= samples.size()/step) return 0;
    return quint8(samples.constData()[sample*step]);
}
inline quint8 atDisplayDepth(const QByteArray& samples,
                            int version,
                            double offsetMeters,
                            double resolutionMeters,
                            double depthMeters,
                            double pixelDepthMeters) {
    const int stride=version==1?2:1;
    const int n=samples.size()/stride;
    if (n<=0 || !(resolutionMeters>0) || !(pixelDepthMeters>0) ||
        !std::isfinite(depthMeters) || !std::isfinite(offsetMeters)) return 0;
    const double begin=(depthMeters-offsetMeters)/resolutionMeters;
    const double span=pixelDepthMeters/resolutionMeters;
    if (begin >= n || begin+span<=0) return 0;
    if (span>=0.8) {
        const int left=std::max(0,int(std::floor(begin)));
        const int right=std::min(n,int(std::ceil(begin+span)));
        if (left>=right) return 0;
        int sum=0;
        for(int i=left;i<right;++i)sum+=at(samples,i,stride);
        return quint8(sum/(right-left));
    }
    // Kogger-style interpolation for enlargement: do NOT quantise to 4 bins.
    if(begin<0 || begin>n-1)return 0;
    const int a=int(std::floor(begin));
    const int b=std::min(n-1,a+1);
    const double t=begin-a;
    return quint8(std::clamp(qRound(at(samples,a,stride)*(1-t)+at(samples,b,stride)*t),0,255));
}
}
