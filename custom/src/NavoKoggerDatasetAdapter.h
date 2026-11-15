#pragma once
#include "NavoKoggerDecoder.h"
#include <QByteArray>
#include <QDateTime>
#include <QVector>
#include <QtGlobal>
#include <cmath>
#include <cstdint>
// Native Kogger Dataset dependencies are now included in the Android target.
#include "../../third_party/KoggerApp/src/epoch.h"
#include "../../third_party/KoggerApp/src/dataset.h"

// Native input records for the upstream KoggerApp Epoch/Dataset pipeline.
// This transport boundary does not fabricate timestamps, channel IDs or GPS.
struct NavoKoggerChartRecord {
    QByteArray chart;
    quint16 resolutionMm = 0;
    quint16 absoluteOffset = 0;
    quint8 version = 0;
    quint64 sequence = 0;
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
    // Bound raw CHART memory separately from the number of epochs. A long
    // high-resolution scan must not retain gigabytes on the G20.
    static constexpr int MaxRecords = 3000;
    static constexpr qsizetype MaxRawBytes = 16 * 1024 * 1024;
    bool append(const NavoKoggerDecoder& decoder, double latitude, double longitude,
                qint64 receivedAtMs = QDateTime::currentMSecsSinceEpoch()) {
        NavoKoggerChartRecord record;
        record.chart = decoder.chartRawBytes(); // QByteArray owns the raw bytes.
        record.resolutionMm = decoder.chartResolution();
        record.absoluteOffset = decoder.chartAbsoluteOffset();
        record.version = decoder.chartVersion();
        record.sequence = decoder.chartSequence();
        record.receivedAtMs = receivedAtMs;
        record.latitude = latitude;
        record.longitude = longitude;
        record.depthM = decoder.depthM();
        record.temperatureC = decoder.waterTempC();
        if (!record.hasValidChart()) return false;
        if (record.chart.size() > MaxRawBytes) return false;
        while (!records_.isEmpty() &&
               (records_.size() >= MaxRecords ||
                rawBytes_ + record.chart.size() > MaxRawBytes)) {
            rawBytes_ -= records_.first().chart.size();
            records_.remove(0);
        }
        rawBytes_ += record.chart.size();
        records_.append(record);
        return true;
    }
    // Mirror the existing decoder's v1 amplitude semantics: in two-byte
    // samples the first byte is the 8-bit echogram amplitude. Keep original
    // CHART bytes unchanged for recording and integrity checks.
    static QVector<uint8_t> displayAmplitudes(const NavoKoggerChartRecord& record) {
        QVector<uint8_t> amplitude;
        if (!record.hasValidChart()) return amplitude;
        const int step = record.version == 1 ? 2 : 1;
        amplitude.reserve(record.chart.size() / step);
        for (qsizetype i = 0; i + step - 1 < record.chart.size(); i += step)
            amplitude.append(quint8(record.chart.at(i)));
        return amplitude;
    }

    // Construct an upstream Epoch without inventing a device timestamp or
    // channel UUID. Caller supplies the real connection/channel identity.
    static bool toKoggerEpoch(const NavoKoggerChartRecord& record,
                              const ChannelId& channel, Epoch& epoch) {
        if (!record.hasValidChart() || !channel.isValid()) return false;
        const QVector<uint8_t> amplitude = displayAmplitudes(record);
        if (amplitude.isEmpty()) return false;
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
    // Use the original Dataset ingestion API, which handles channel setup,
    // Epoch allocation and downstream DataProcessor notifications itself.
    // CHART v0/v1 share the decoder's amplitude interpretation.
    static bool appendToKoggerDataset(const NavoKoggerChartRecord& record,
                                     const ChannelId& channel, Dataset& dataset) {
        if (!record.hasValidChart() || !channel.isValid()) return false;
        const QVector<uint8_t> amplitude = displayAmplitudes(record);
        if (amplitude.isEmpty()) return false;
        const float resolutionM = float(record.resolutionMm) * 0.001f;
        const float offsetM = float(record.absoluteOffset) * resolutionM;
        dataset.addChart(channel, ChartParameters{},
                         QVector<QVector<uint8_t>>{amplitude}, resolutionM, offsetM);
        if (record.hasPosition())
            dataset.addPosition(record.latitude, record.longitude);
        if (std::isfinite(record.depthM) && record.depthM >= 0)
            dataset.addDepth(float(record.depthM));
        if (std::isfinite(record.temperatureC))
            dataset.addTemp(float(record.temperatureC));
        return true;
    }
    const QVector<NavoKoggerChartRecord>& records() const { return records_; }
    qsizetype retainedRawBytes() const { return rawBytes_; }
    void clear() { records_.clear(); rawBytes_ = 0; }
private:
    QVector<NavoKoggerChartRecord> records_;
    qsizetype rawBytes_ = 0;
};
