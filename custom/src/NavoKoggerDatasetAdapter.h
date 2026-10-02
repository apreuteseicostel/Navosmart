#pragma once
#include "NavoKoggerDecoder.h"
#include <QByteArray>
#include <QDateTime>
#include <QVector>
#include <QtGlobal>
#include <cmath>
#include <cstdint>
#include "../../third_party/KoggerApp/src/epoch.h"

// Native input records for the upstream KoggerApp Epoch/Dataset pipeline.
// This transport boundary does not fabricate timestamps, channel IDs or GPS.
struct NavoKoggerChartRecord {
    QByteArray chart;
    quint16 resolutionMm = 0;
    quint16 absoluteOffset = 0;
    quint8 version = 0;
    qint64 receivedAtMs = 0; // Host arrival time; not a sonar-device timestamp.
    double latitude = qQNaN();
    double longitude = qQNaN();
    double depthM = qQNaN();
    double temperatureC = qQNaN();
    bool hasPosition() const {
        return std::isfinite(latitude) && std::isfinite(longitude)
            && latitude >= -90 && latitude <= 90
            && longitude >= -180 && longitude <= 180;
    }
    bool hasValidChart() const {
        return !chart.isEmpty() && resolutionMm > 0 && version <= 1
            && (version != 1 || chart.size() % 2 == 0);
    }
};

class NavoKoggerDatasetAdapter {
public:
    static constexpr int MaxRecords = 3000;
    bool append(const NavoKoggerDecoder& decoder, double latitude, double longitude,
                qint64 receivedAtMs = QDateTime::currentMSecsSinceEpoch()) {
        NavoKoggerChartRecord record;
        record.chart = decoder.chartRawBytes(); // QByteArray owns the raw bytes.
        record.resolutionMm = decoder.chartResolution();
        record.absoluteOffset = decoder.chartAbsoluteOffset();
        record.version = decoder.chartVersion();
        record.receivedAtMs = receivedAtMs;
        record.latitude = latitude;
        record.longitude = longitude;
        record.depthM = decoder.depthM();
        record.temperatureC = decoder.waterTempC();
        if (!record.hasValidChart()) return false;
        if (records_.size() >= MaxRecords) records_.remove(0);
        records_.append(record);
        return true;
    }
    // Construct an upstream Epoch without inventing a device timestamp or
    // channel UUID. Caller supplies the real connection/channel identity.
    // Kogger CHART v1 contains two-byte samples: decoding its amplitude
    // semantics must be validated before it can enter an 8-bit Echogram.
    static bool toKoggerEpoch(const NavoKoggerChartRecord& record,
                              const ChannelId& channel, Epoch& epoch) {
        if (!record.hasValidChart() || !channel.isValid() || record.version != 0)
            return false;
        QVector<uint8_t> amplitude;
        amplitude.reserve(record.chart.size());
        for (const char byte : record.chart)
            amplitude.append(static_cast<uint8_t>(byte));
        const float resolutionM = float(record.resolutionMm) * 0.001f;
        const float offsetM = float(record.absoluteOffset) * resolutionM;
        epoch.setChart(channel, QVector<QVector<uint8_t>>{amplitude},
                       resolutionM, offsetM);
        if (record.hasPosition())
            epoch.setPositionLLA(record.latitude, record.longitude);
        if (std::isfinite(record.depthM) && record.depthM >= 0)
            epoch.setDepth(float(record.depthM));
        if (std::isfinite(record.temperatureC))
            epoch.setTemp(float(record.temperatureC));
        return true;
    }
    const QVector<NavoKoggerChartRecord>& records() const { return records_; }
    void clear() { records_.clear(); }
private:
    QVector<NavoKoggerChartRecord> records_;
};
