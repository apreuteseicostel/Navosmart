#pragma once
#include <QColor>
#include <QVector>
#include <QtGlobal>
#include <algorithm>
#include <cmath>

// Original KoggerApp Plot2DEchogram::colormapFor, setColorScheme and
// updateColors algorithms adapted for NAVO's Qt Quick renderer.
// Original project: https://github.com/koggertech/KoggerApp
// Source: src/scene2d/plot2D_echogram.cpp (GPL-3.0)
// Changes: three NAVO-selectable Kogger palettes and bounded lookup only.
// See third_party/KoggerApp/LICENSE. No CHART amplitudes are modified.
namespace NavoKoggerPalette {
inline QVector<QRgb> colors(int theme, float lowPercent, float highPercent) {
    QVector<QColor> stops;
    QVector<int> levels;
    // Kogger original: Classic, Ice and Sepia New palettes.
    if (theme == 1) {
        stops = {
            QColor::fromRgb(0,0,70), QColor::fromRgb(0,40,150),
            QColor::fromRgb(0,100,230), QColor::fromRgb(0,180,255),
            QColor::fromRgb(0,240,255), QColor::fromRgb(80,255,230),
            QColor::fromRgb(170,255,255), QColor::fromRgb(230,255,255),
            QColor::fromRgb(255,255,255)
        };
        levels = {0,30,60,95,130,170,210,235,255};
    } else if (theme == 2) {
        stops = {
            QColor::fromRgb(0,0,0), QColor::fromRgb(28,10,0),
            QColor::fromRgb(55,18,0), QColor::fromRgb(95,35,0),
            QColor::fromRgb(150,70,10), QColor::fromRgb(210,105,15),
            QColor::fromRgb(245,175,70), QColor::fromRgb(255,232,160)
        };
        levels = {0,12,26,52,92,140,200,255};
    } else {
        stops = {
            QColor::fromRgb(0,0,0), QColor::fromRgb(20,5,80),
            QColor::fromRgb(50,180,230), QColor::fromRgb(190,240,250),
            QColor::fromRgb(255,255,255)
        };
        levels = {0,30,130,220,255};
    }
    QVector<QRgb> table(256);
    for (int range = 0; range + 1 < levels.size(); ++range) {
        for (int i = levels[range]; i <= levels[range+1]; ++i) {
            const float t = float(i-levels[range])/float(levels[range+1]-levels[range]);
            const int r = qRound(stops[range].red()*(1-t) + stops[range+1].red()*t);
            const int g = qRound(stops[range].green()*(1-t) + stops[range+1].green()*t);
            const int b = qRound(stops[range].blue()*(1-t) + stops[range+1].blue()*t);
            table[i] = qRgb(r,g,b);
        }
    }
    // Exactly the original Kogger percentage-window mapping (0..100).
    const float low = std::clamp(lowPercent,0.0f,99.0f);
    const float high = std::clamp(highPercent,low+1.0f,100.0f);
    const int indexOffset = int(low*2.5f);
    const float scale = 255.0f/((high-low)*2.55f);
    QVector<QRgb> adjusted(256);
    for (int i=0;i<256;++i) {
        const int index = std::clamp(int(float(i-indexOffset)*scale),0,255);
        adjusted[i] = table[index];
    }
    return adjusted;
}
}
