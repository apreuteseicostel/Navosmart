#pragma once
#include <QObject>
#include <QPointer>
#include <memory>
#include "../../third_party/KoggerApp/src/dataset.h"
#include "../../third_party/KoggerApp/src/data_horizon.h"
#include "../../third_party/KoggerApp/src/data_processor/data_processor.h"
#include "navo_bottom_track.h"
struct NavoKoggerChartRecord;
class NavoKoggerService final : public QObject {
    Q_OBJECT
public:
    static NavoKoggerService& instance();
    explicit NavoKoggerService(QObject* parent=nullptr);
    ~NavoKoggerService() override;
    Dataset& dataset(){return dataset_;}
    MosaicIndexProvider& mosaicIndexProvider(){return processor_->mosaicIndexProvider();}
    bool ingest(const NavoKoggerChartRecord& record, const ChannelId& channel, double heading,double pitch=qQNaN(),double roll=qQNaN());
    void clear();
    void shutdown();
    int processedColumns() const {return processedColumns_;}
    int tileCount() const {return tiles_.size();}
    bool capacityFull() const {return capacityFull_;}
    double bottomDepth() const {return bottomDepth_;}
    void requestVisibleRect(float n0,float e0,float n1,float e1);
    const TileMap& tiles() const {return tiles_;}
    DataProcessor& processor(){return *processor_;}
    DataHorizon& horizon(){return horizon_;}
signals:
    void processingChanged();
    void bottomSampleReady(int epoch,double latitude,double longitude,double depth,double temperature);
    void tilesChanged();
private:
    void startProcessor();
    void rollBatch();
    void onBottomUpdated(const ChannelId& channel,int from,int to,bool manual,bool redraw);
    Dataset dataset_;
    DataHorizon horizon_;
    BottomTrack bottomTrack_;
    std::unique_ptr<DataProcessor> processor_;
    TileMap tiles_;
    ChannelId channel_;
    qsizetype rawBytes_=0;
    int processedColumns_=0;
    bool capacityFull_=false;
    double bottomDepth_=qQNaN();
    QTimer rolloverTimer_;
    struct PendingInput {QByteArray chart;quint16 resolution,offset;quint8 version; qint64 time;double lat,lon,depth,temp,heading,pitch,roll;ChannelId channel;};
    QVector<PendingInput> pending_;
    qsizetype pendingBytes_=0;
    bool rolling_=false;
    int epochOffset_=0;
    QSet<int> processedEpochs_;
};
