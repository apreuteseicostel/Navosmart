#include "NavoKoggerService.h"
#include "../src/NavoKoggerDatasetAdapter.h"
#include <QCoreApplication>
#include <cmath>
NavoKoggerService& NavoKoggerService::instance(){
    static QPointer<NavoKoggerService> service;
    if(!service)service=new NavoKoggerService(QCoreApplication::instance());
    return *service;
}
NavoKoggerService::NavoKoggerService(QObject* parent):QObject(parent){
    connect(&dataset_,&Dataset::epochAdded,&horizon_,&DataHorizon::onAddedEpoch);
    connect(&dataset_,&Dataset::positionAdded,&horizon_,&DataHorizon::onAddedPosition);
    connect(&dataset_,&Dataset::chartAdded,&horizon_,&DataHorizon::onAddedChart);
    connect(&dataset_,&Dataset::attitudeAdded,&horizon_,&DataHorizon::onAddedAttitude);
    connect(&dataset_,&Dataset::artificalAttitudeAdded,&horizon_,&DataHorizon::onAddedArtificalAttitude);
    connect(&dataset_,&Dataset::bottomTrackAdded,&horizon_,&DataHorizon::onAddedBottomTrack);
    connect(&horizon_,&DataHorizon::sonarPosCanCalc,&dataset_,&Dataset::onSonarPosCanCalc);
    connect(&horizon_,&DataHorizon::dimRectsCanCalc,&dataset_,&Dataset::onDimensionRectCanCalc);
    connect(&dataset_,&Dataset::bottomTrackUpdated,this,&NavoKoggerService::onBottomUpdated);
    qRegisterMetaType<BottomTrack*>("BottomTrack*");
    connect(QCoreApplication::instance(),&QCoreApplication::aboutToQuit,this,&NavoKoggerService::shutdown);
    rolloverTimer_.setInterval(20);
    connect(&rolloverTimer_,&QTimer::timeout,this,&NavoKoggerService::rollBatch);
    startProcessor();
}
NavoKoggerService::~NavoKoggerService(){shutdown();}
void NavoKoggerService::shutdown(){rolloverTimer_.stop();if(processor_)processor_->shutdown();}
void NavoKoggerService::startProcessor(){
    processor_=std::make_unique<DataProcessor>(nullptr,&dataset_);
    auto* p=processor_.get();
    connect(&horizon_,&DataHorizon::chartAdded,p,&DataProcessor::onChartsAdded,Qt::QueuedConnection);
    connect(&horizon_,&DataHorizon::epochAdded,p,&DataProcessor::onEpochAdded,Qt::QueuedConnection);
    connect(&horizon_,&DataHorizon::mosaicCanCalc,p,&DataProcessor::onMosaicCanCalc,Qt::QueuedConnection);
    connect(&horizon_,&DataHorizon::bottomTrack3DAdded,p,&DataProcessor::onBottomTrack3DAdded,Qt::QueuedConnection);
    connect(&dataset_,&Dataset::sendTilesByZoom,p,&DataProcessor::onSendTilesByZoom,Qt::QueuedConnection);
    connect(&dataset_,&Dataset::datasetStateChanged,p,&DataProcessor::onDatasetStateChanged,Qt::QueuedConnection);
    connect(p,&DataProcessor::distCompletedByProcessing,&dataset_,&Dataset::onDistCompleted);
    connect(p,&DataProcessor::distCompletedByProcessingBatch,&dataset_,&Dataset::onDistCompletedBatch);
    connect(p,&DataProcessor::lastBottomTrackEpochChanged,&dataset_,&Dataset::onLastBottomTrackEpochChanged);
    connect(p,&DataProcessor::sendSurfaceTiles,this,[this](const TileMap& tiles,bool){
        // Only retain a bounded visible tile set, not an unbounded scan archive.
        for(auto it=tiles.cbegin();it!=tiles.cend();++it){
            if(tiles_.size()>=128&&!tiles_.contains(it.key()))tiles_.erase(tiles_.begin());
            tiles_.insert(it.key(),it.value());
        }
        emit tilesChanged();emit processingChanged();
    });
    connect(p,&DataProcessor::sendSurfaceTilesIncremental,this,[this](const TileMap& upserts,const QSet<TileKey>& visible){
        for(auto it=tiles_.begin();it!=tiles_.end();)if(!visible.contains(it.key()))it=tiles_.erase(it);else ++it;
        for(auto it=upserts.cbegin();it!=upserts.cend();++it){
            if(tiles_.size()>=128&&!tiles_.contains(it.key()))tiles_.erase(tiles_.begin());
            tiles_.insert(it.key(),it.value());
        }
        emit tilesChanged();emit processingChanged();
    });
    p->setBottomTrackPtr(&bottomTrack_);
    p->setUpdateBottomTrack(true);
    p->setUpdateMosaic(false);
    // DownView is a downward beam. Derive bathymetry from located depths;
    // never project its samples as a fabricated lateral side-scan swath.
    p->setUpdateSurface(true);
    p->setUpdateIsobaths(false);
    dataset_.setState(Dataset::DatasetState::kConnection);
}
bool NavoKoggerService::ingest(const NavoKoggerChartRecord& record,const ChannelId& channel,double heading,double pitch,double roll){
    if(!record.hasValidChart()||!channel.isValid()||record.version!=0)return false;
    if(channel_.isValid()&&channel_!=channel)clear();
    if(rolling_ || capacityFull_ || dataset_.size()>=3000 || rawBytes_+record.chart.size()>16*1024*1024){
        capacityFull_=true;
        if(pending_.size()>=64 || pendingBytes_+record.chart.size()>1024*1024){emit processingChanged();return false;}
        pending_.append(PendingInput{record.chart,record.resolutionMm,record.absoluteOffset,record.version,
            record.receivedAtMs,record.latitude,record.longitude,record.depthM,record.temperatureC,heading,pitch,roll,channel});
        pendingBytes_+=record.chart.size();
        if(!rolloverTimer_.isActive())rolloverTimer_.start();
        emit processingChanged();return true;
    }
    if(!channel_.isValid()){
        channel_=channel;
        // Side-scan channels are intentionally unconfigured for DownView.
    }
    if(!NavoKoggerDatasetAdapter::appendToKoggerDataset(record,channel,dataset_))return false;
    rawBytes_+=record.chart.size();
    if(std::isfinite(heading))dataset_.addAtt(heading,pitch,roll);
    return true;
}
void NavoKoggerService::rollBatch(){
    if(rolling_ || dataset_.getLastBottomTrackEpoch()<dataset_.size())return;
    rolling_=true;rolloverTimer_.stop();
    // The original live scene deliberately trails three epochs. At the closed
    // batch boundary these already processed tail depths can be published.
    onBottomUpdated(channel_,std::max(0,dataset_.size()-3),dataset_.size(),false,false);
    const int previousSize=dataset_.size();const auto reference=dataset_.getLlaRef();
    processor_->setSuppressResults(true);
    QObject::disconnect(processor_.get(),nullptr,&dataset_,nullptr);
    QObject::disconnect(processor_.get(),nullptr,this,nullptr);
    processor_->shutdown();processor_.reset();
    dataset_.resetDataset();horizon_.clear();bottomTrack_.clear();
    if(reference.isInit)dataset_.setLlaRef(reference,Dataset::LlaRefState::kSettings);
    epochOffset_+=previousSize;processedEpochs_.clear();rawBytes_=0;
    startProcessor();
    const auto pending=std::move(pending_);pending_.clear();pendingBytes_=0;
    rolling_=false;capacityFull_=false;
    for(const auto& input:pending){
        NavoKoggerChartRecord record;
        record.chart=input.chart;record.resolutionMm=input.resolution;record.absoluteOffset=input.offset;record.version=input.version;
        record.receivedAtMs=input.time;record.latitude=input.lat;record.longitude=input.lon;record.depthM=input.depth;record.temperatureC=input.temp;
        ingest(record,input.channel,input.heading,input.pitch,input.roll);
    }
    emit processingChanged();
}
void NavoKoggerService::clear(){
    rolloverTimer_.stop();pending_.clear();pendingBytes_=0;rolling_=false;epochOffset_=0;processedEpochs_.clear();
    // Stop workers before clearing the shared Dataset; reconnect starts a new
    // generation, so queued results cannot mutate epochs from another scan.
    processor_->setSuppressResults(true);
    QObject::disconnect(processor_.get(),nullptr,&dataset_,nullptr);
    QObject::disconnect(processor_.get(),nullptr,this,nullptr);
    processor_->shutdown();processor_.reset();
    dataset_.resetDataset();horizon_.clear();bottomTrack_.clear();tiles_.clear();
    rawBytes_=0;processedColumns_=0;capacityFull_=false;bottomDepth_=qQNaN();channel_.clear();
    startProcessor();emit processingChanged();emit tilesChanged();
}
void NavoKoggerService::onBottomUpdated(const ChannelId& channel,int from,int to,bool manual,bool){
    QVector<int> epochs,vertices;
    for(int index=std::max(0,from);index<std::min(to,dataset_.size());++index){
        Epoch epoch=dataset_.fromIndexCopy(index);
        const double depth=epoch.distProccesing(channel);
        if(!std::isfinite(depth)||depth<=0)continue;
        bottomDepth_=depth;
        if(!processedEpochs_.contains(index)){processedEpochs_.insert(index);++processedColumns_;}
        const auto position=epoch.getSonarPosition();
        if(position.ned.isCoordinatesValid()){
            epochs.append(index);vertices.append(bottomTrack_.put(index,QVector3D(position.ned.n,position.ned.e,-depth)));
        }
        const auto gps=epoch.getPositionGNSS();
        if(gps.lla.isCoordinatesValid())emit bottomSampleReady(epochOffset_+index,gps.lla.latitude,gps.lla.longitude,depth,epoch.temperature());
    }
    if(!epochs.isEmpty())horizon_.onAddedBottomTrack3D(epochs,vertices,manual);
    emit processingChanged();
}
void NavoKoggerService::requestVisibleRect(float n0,float e0,float n1,float e1){processor_->onSendDataRectRequest(n0,e0,n1,e1);}
