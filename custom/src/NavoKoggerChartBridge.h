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
    Q_PROPERTY(bool channelReady READ channelReady NOTIFY recordsChanged)
    Q_PROPERTY(double bottomDepthM READ bottomDepthM NOTIFY recordsChanged)
    Q_PROPERTY(int processedColumns READ processedColumns NOTIFY recordsChanged)
    Q_PROPERTY(int bathymetryTileCount READ bathymetryTileCount NOTIFY recordsChanged)
    Q_PROPERTY(int mosaicTileCount READ mosaicTileCount NOTIFY recordsChanged)
    Q_PROPERTY(bool capacityFull READ capacityFull NOTIFY recordsChanged)
    Q_PROPERTY(int recordCount READ recordCount NOTIFY recordsChanged)
    Q_PROPERTY(qint64 retainedRawBytes READ retainedRawBytes NOTIFY recordsChanged)
    Q_PROPERTY(int rejectedColumns READ rejectedColumns NOTIFY recordsChanged)
    Q_PROPERTY(int unlocatedColumns READ unlocatedColumns NOTIFY recordsChanged)
    Q_PROPERTY(int epochConversionFailures READ epochConversionFailures NOTIFY recordsChanged)
    Q_PROPERTY(int datasetColumns READ datasetColumns NOTIFY recordsChanged)
public:
    explicit NavoKoggerChartBridge(QObject* parent = nullptr) : QObject(parent) {
        auto& service=NavoKoggerService::instance();
        QObject::connect(&service,&NavoKoggerService::processingChanged,this,&NavoKoggerChartBridge::recordsChanged);
        QObject::connect(&service,&NavoKoggerService::geoSampleReady,this,&NavoKoggerChartBridge::geoSampleReady);
        QObject::connect(&service,&NavoKoggerService::bottomColumnReady,this,&NavoKoggerChartBridge::bottomColumnReady);
    }
    bool channelReady() const {return !linkUuid_.isNull() && decoder_ && decoder_->chartAddress()>=0;}
    double bottomDepthM() const {return NavoKoggerService::instance().bottomDepth();}
    int processedColumns() const {return NavoKoggerService::instance().processedColumns();}
    int mosaicTileCount() const {return 0;}
    int bathymetryTileCount() const {return NavoKoggerService::instance().tileCount();}
    bool capacityFull() const {return NavoKoggerService::instance().capacityFull();}
    Q_INVOKABLE void setConnectionEndpoint(const QString& host,int port,bool udp) {
        const QUuid previous=linkUuid_;
        const QString name=host.trimmed().toLower();
        linkUuid_=(name.isEmpty()||port<1||port>65535)?QUuid():QUuid::createUuidV5(
            QUuid("{6ba7b811-9dad-11d1-80b4-00c04fd430c8}"),
            QString("navo-kogger+%1://%2:%3").arg(udp?"udp":"tcp",name).arg(port).toUtf8());
        if(previous!=linkUuid_)clear();
        emit recordsChanged();
    }
    int recordCount() const { return adapter_.records().size(); }
    qint64 retainedRawBytes() const { return adapter_.retainedRawBytes(); }
    int rejectedColumns() const { return rejected_; }
    int unlocatedColumns() const { return unlocated_; }
    int epochConversionFailures() const { return epochFailures_; }
    int datasetColumns() const { return datasetColumns_; }
    Q_INVOKABLE void setDecoder(NavoKoggerDecoder* decoder) {
        if (connection_) QObject::disconnect(connection_);
        decoder_ = decoder;
        if (decoder_)
            connection_ = QObject::connect(decoder_, &NavoKoggerDecoder::chartColumnReady,
                                           this, &NavoKoggerChartBridge::capture);
    }
    Q_INVOKABLE void setPosition(double latitude, double longitude, double heading=qQNaN(), double pitch=qQNaN(), double roll=qQNaN()) {
        latitude_ = latitude;
        longitude_ = longitude;
        heading_=heading;pitch_=pitch;roll_=roll;
        positionUpdatedAt_=QDateTime::currentMSecsSinceEpoch();
    }
    Q_INVOKABLE void clear() {
        adapter_.clear();
        NavoKoggerService::instance().clear();
        rejected_ = 0;
        unlocated_ = 0;
        epochFailures_ = 0;
        datasetColumns_ = 0;
        emit recordsChanged();
    }
signals:
    void recordsChanged();
    void geoSampleReady(const QVariantMap& sample);
    void bottomColumnReady(quint64 sequence,double depth);
private:
    void capture() {
        if (!decoder_) return;
        const bool fresh=QDateTime::currentMSecsSinceEpoch()-positionUpdatedAt_<=2000;
        if (!adapter_.append(*decoder_, fresh?latitude_:qQNaN(), fresh?longitude_:qQNaN())) {
            ++rejected_;
        } else {
            const auto& record = adapter_.records().last();
            if (!record.hasPosition()) ++unlocated_;
            const int address=decoder_->chartAddress();
            const ChannelId channel=(!linkUuid_.isNull()&&address>=0&&address<=255)
                ?ChannelId(linkUuid_,quint8(address)):ChannelId();
            if(channel.isValid()){
                if(record.version!=0)++epochFailures_;
                else if(NavoKoggerService::instance().ingest(record,channel,
                            fresh?heading_:qQNaN(),fresh?pitch_:qQNaN(),fresh?roll_:qQNaN()))++datasetColumns_;
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
    QUuid linkUuid_;
    qint64 positionUpdatedAt_=0;
    double heading_=qQNaN(),pitch_=qQNaN(),roll_=qQNaN();
};
