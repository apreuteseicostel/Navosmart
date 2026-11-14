#pragma once
#include <QVariantMap>
#include <QVariantList>
#include <QVector3D>
#include <QVector>
#include <cmath>
#include <algorithm>
#include "navo_surface_mesh.h"

// Convert native Kogger IsobathsProcessor N/E/depth line pairs into GPS lines.
// Rendering is strictly bounded and never fills missing position/depth values.
inline QVariantMap navoNativeIsobaths(const QVector<QVector3D>& pairs,
                                      const LLARef& reference,
                                      double stepMeters,
                                      int maxSegments = 4000) {
    QVariantList segments;
    bool truncated = false;
    if (!reference.isInit || !reference.refLla.isCoordinatesValid() ||
        !std::isfinite(stepMeters) || stepMeters < 0.5 || stepMeters > 5.0 ||
        maxSegments <= 0) {
        return {{"version", 1}, {"source", "kogger-native-isobaths"},
                {"segments", segments}, {"stepMeters", stepMeters},
                {"truncated", false}};
    }
    const int count = pairs.size() / 2;
    for (int i = 0; i < count; ++i) {
        const auto a = pairs[2 * i], b = pairs[2 * i + 1];
        if (!std::isfinite(a.x()) || !std::isfinite(a.y()) || !std::isfinite(a.z()) ||
            !std::isfinite(b.x()) || !std::isfinite(b.y()) || !std::isfinite(b.z()))
            continue;
        // Native Kogger uses negative Z for depth and adds +0.03 m for line offset.
        const double depth = -(double(a.z()) + double(b.z())) / 2.0 + 0.03;
        if (!std::isfinite(depth) || depth <= 0 || depth > 1000 ||
            std::abs(double(a.z())-double(b.z())) > 0.15)
            continue;
        const NED neda(a.x(), a.y(), -a.z());
        const NED nedb(b.x(), b.y(), -b.z());
        const LLA la(&neda, &reference), lb(&nedb, &reference);
        if (!la.isCoordinatesValid() || !lb.isCoordinatesValid() ||
            std::abs(la.latitude) > 90 || std::abs(lb.latitude) > 90 ||
            std::abs(la.longitude) > 180 || std::abs(lb.longitude) > 180)
            continue;
        if (segments.size() >= maxSegments) { truncated = true; break; }
        const double level = std::round(depth / stepMeters) * stepMeters;
        segments.append(QVariant(QVariantList{
            la.latitude, la.longitude, lb.latitude, lb.longitude, level
        }));
    }
    return {{"version", 1}, {"source", "kogger-native-isobaths"},
            {"segments", segments}, {"stepMeters", stepMeters},
            {"truncated", truncated}};
}
