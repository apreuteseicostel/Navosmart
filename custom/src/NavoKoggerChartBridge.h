#pragma once
#include "NavoKoggerDatasetAdapter.h"
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
public:
    explicit NavoKoggerChartBridge(QObject* parent = nullptr) : QObject(parent) {}
    int recordCount() const { return adapter_.records().size(); }
    qint64 retainedRawBytes() const { return adapter_.retainedRawBytes(); }
    int rejectedColumns() const { return rejected_; }
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
        emit recordsChanged();
    }
signals:
    void recordsChanged();
private:
    void capture() {
        if (!decoder_) return;
        if (!adapter_.append(*decoder_, latitude_, longitude_))
            ++rejected_;
        emit recordsChanged();
    }
    QPointer<NavoKoggerDecoder> decoder_;
    QMetaObject::Connection connection_;
    NavoKoggerDatasetAdapter adapter_;
    double latitude_ = qQNaN();
    double longitude_ = qQNaN();
    int rejected_ = 0;
};
