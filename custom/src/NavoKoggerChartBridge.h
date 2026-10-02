#pragma once
#include "NavoKoggerDatasetAdapter.h"
#include "../kogger_native/NavoKoggerService.h"
#include <QObject>
#include <QPointer>
#include <QMetaObject>
#include <cmath>

// Live input bridge. Upstream Dataset processing is enabled only after the
// complete KoggerApp dependency tree passes the Android build.
class NavoKoggerChartBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(int recordCount READ recordCount NOTIFY recordsChanged)
    Q_PROPERTY(qint64 retainedRawBytes READ retainedRawBytes NOTIFY recordsChanged)
    Q_PROPERTY(int rejectedColumns READ rejectedColumns NOTIFY recordsChanged)
    Q_PROPERTY(int unlocatedColumns READ unlocatedColumns NOTIFY recordsChanged)
    Q_PROPERTY(int epochConversionFailures READ epochConversionFailures NOTIFY recordsChanged)
    Q_PROPERTY(int datasetColumns READ datasetColumns NOTIFY recordsChanged)
public:
    explicit NavoKoggerChartBridge(QObject* parent = nullptr) : QObject(parent) {}
    int recordCount() const { return adapter_.records().size(); }
    qint64 retainedRawBytes() const { return adapter_.retainedRawBytes(); }
    int rejectedColumns() const { return rejected_; }
    int unlocatedColumns() const { return unlocated_; }
    int epochConversionFailures() const { return epochFailures_; }
    int datasetColumns() const { return datasetColumns_; }
    Q_INVOKABLE void setChannelIdentity(const QString& uuid, int address) {
        const QUuid parsed(uuid);
        channel_ = (!parsed.isNull() && address >= 0 && address <= 255)
            ? ChannelId(parsed, static_cast<uint8_t>(address)) : ChannelId();
    }
    Q_INVOKABLE void setDecoder(NavoKoggerDecoder* decoder) {
        if (connection_) QObject::disconnect(connection_);
        decoder_ = decoder;
        if (decoder_)
            connection_ = QObject::connect(decoder_, &NavoKoggerDecoder::chartColumnReady,
                                           this, &NavoKoggerChartBridge::capture);
    }
    Q_INVOKABLE void setPosition(double latitude, double longitude) {
        latitude_ = latitude;
        longitude_ = longitude;
    }
    Q_INVOKABLE void clear() {
        adapter_.clear();
        rejected_ = 0;
        unlocated_ = 0;
        epochFailures_ = 0;
        datasetColumns_ = 0;
        emit recordsChanged();
    }
signals:
    void recordsChanged();
private:
    void capture() {
        if (!decoder_) return;
        if (!adapter_.append(*decoder_, latitude_, longitude_)) {
            ++rejected_;
        } else {
            const auto& record = adapter_.records().last();
            if (!record.hasPosition()) ++unlocated_;
            // No fabricated UUID: only convert once the real sonar channel
            // identity has been supplied by connection configuration.
            if (channel_.isValid()) {
                Epoch epoch;
                if (!NavoKoggerDatasetAdapter::toKoggerEpoch(record, channel_, epoch)) {
                    ++epochFailures_;
                } else if (NavoKoggerDatasetAdapter::appendToKoggerDataset(
                               record, channel_, NavoKoggerService::instance().dataset())) {
                    ++datasetColumns_;
                }
            }
        }
        emit recordsChanged();
    }
    QPointer<NavoKoggerDecoder> decoder_;
    QMetaObject::Connection connection_;
    NavoKoggerDatasetAdapter adapter_;
    double latitude_ = qQNaN();
    double longitude_ = qQNaN();
    int rejected_ = 0;
    int unlocated_ = 0;
    int epochFailures_ = 0;
    int datasetColumns_ = 0;
    ChannelId channel_;
};
