#include "../../custom/src/NavoKoggerDecoder.h"
#include <QGuiApplication>
#include "../../custom/src/NavoKoggerDatasetAdapter.h"
#include <QCryptographicHash>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QElapsedTimer>
#include <QThread>
#include <QEventLoop>
#include <QtEndian>
#include <cstring>
#include "../../custom/kogger_native/NavoKoggerService.h"
#include <iostream>
#include <stdexcept>
#include <algorithm>

static void require(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}
static void u16(QByteArray& bytes, quint16 value) {
    bytes.append(char(value & 255)); bytes.append(char(value >> 8));
}
static QByteArray frame(bool kp2, quint16 seq, const QByteArray& data, int type=1) {
    QByteArray payload; u16(payload,seq); u16(payload,10); u16(payload,0); payload+=data;
    QByteArray f;
    if(kp2) {
        f=QByteArray::fromHex("cc550000030000");
        f.append(char(type)); u16(f,24); f+=payload;
        const int size=f.size()+2; f[2]=char(size&255); f[3]=char(size>>8);
    } else {
        f=QByteArray::fromHex("bb5500010300"); f[3]=char(type);
        f[5]=char(payload.size()); f+=payload;
    }
    quint8 a=0,b=0;
    for(int i=2;i<f.size();++i){a=quint8(a+quint8(f[i]));b=quint8(b+a);}
    f.append(char(a));f.append(char(b));return f;
}
static void synthetic() {
    for(bool kp2 : {false,true}) {
        NavoKoggerDecoder d; int count=0;
        QObject::connect(&d,&NavoKoggerDecoder::chartColumnReady,[&]{++count;});
        const QByteArray stream=frame(kp2,0,QByteArray::fromHex("1020"))+
            frame(kp2,4,QByteArray::fromHex("3040"))+frame(kp2,0,QByteArray::fromHex("5060"));
        for(const char b:stream)d.feedBytes(QByteArray(1,b));
        require(count==1,"split headers and payloads lost a column");
        require(d.chartRawBytes()==QByteArray::fromHex("102000003040"),"lost fragment offset was not preserved");
        require(d.chartResolution()==10 && std::abs(d.chartRangeMeters()-0.06)<1e-9,"physical scale changed");
        QByteArray corrupt=frame(kp2,0,QByteArray::fromHex("7080")); corrupt[corrupt.size()-1]=char(quint8(corrupt[corrupt.size()-1])^1);
        d.feedBytes(corrupt+frame(kp2,0,QByteArray::fromHex("90a0")));
        require(count==2 && d.chartRawBytes()==QByteArray::fromHex("5060"),"checksum resynchronization failed");
        d.feedBytes(frame(kp2,0,QByteArray::fromHex("b0c0"),2));
        require(count==2,"setting response became a measurement");
        d.reset(); require(!d.connected() && d.chartRawBytes().isEmpty(),"reset retained old recording");
    }
    std::cout<<"PASS KP1/KP2 fragmentation, missing fragments, checksum recovery, type filter and reset\n";
}
struct Result { qint64 columns=0; QByteArray hash; };
static Result replay(const QByteArray& bytes, bool fragmented) {
    NavoKoggerDecoder d; Result result; QCryptographicHash hash(QCryptographicHash::Sha256);
    NavoKoggerDatasetAdapter adapter;
    Dataset dataset;
    // Test-only channel identity for this fixture, never a live connection UUID.
    const ChannelId channel(QUuid("{52202375-23b1-44cb-83a8-d2b8611efbab}"),0);
    QObject::connect(&d,&NavoKoggerDecoder::chartColumnReady,[&]{
        require(d.chartVersion()==0,"unexpected published version");
        require(d.chartResolution()==10 && d.chartAbsoluteOffset()==0,"unexpected CHART metadata");
        require(d.chartRawBytes().size()==5000,"unexpected column length");
        require(adapter.append(d,qQNaN(),qQNaN(),0),"adapter rejected fixture column");
        const auto& record=adapter.records().last();
        require(!record.hasPosition(),"replay fabricated GPS");
        Epoch epoch;
        require(!NavoKoggerDatasetAdapter::toKoggerEpoch(record,ChannelId(),epoch),"invalid channel was accepted");
        require(NavoKoggerDatasetAdapter::toKoggerEpoch(record,channel,epoch),"Epoch conversion failed");
        const auto* chart=epoch.chart(channel,0);
        require(chart && chart->amplitude.size()==5000 && std::abs(chart->resolution-0.01f)<1e-6f,
                "Epoch lost chart samples or physical scale");
        for(int i=0;i<5000;++i)
            require(chart->amplitude[i]==quint8(record.chart[i]),"Epoch modified raw amplitude");
        require(NavoKoggerDatasetAdapter::appendToKoggerDataset(record,channel,dataset),"Dataset ingestion failed");
        const auto latest=dataset.fromIndexCopy(dataset.endIndex());
        Epoch copy=latest;
        const auto* stored=copy.chart(channel,0);
        require(stored && stored->amplitude==chart->amplitude,"Dataset/Epoch chart differs");
        // Bound test Dataset batches; this does not claim production eviction.
        if(dataset.size()>=128)dataset.resetDataset();
        hash.addData(d.chartRawBytes()); ++result.columns;
    });
    if(!fragmented)d.feedBytes(bytes);
    else {
        const int sizes[]={1,13,4096,257,23}; int index=0;
        for(qsizetype offset=0;offset<bytes.size();){
            const qsizetype size=std::min(qsizetype(sizes[index++%5]),bytes.size()-offset);
            d.feedBytes(bytes.mid(offset,size));offset+=size;
        }
    }
    require(adapter.records().size()==3000 && adapter.retainedRawBytes()==15000000,
            "adapter retention budget failed");
    result.hash=hash.result().toHex();return result;
}
static void recordedProcessors(const QByteArray& bytes) {
    auto& service=NavoKoggerService::instance();service.clear();
    NavoKoggerDecoder decoder;
    const ChannelId channel(QUuid("{52202375-23b1-44cb-83a8-d2b8611efbab}"),2);
    double lat=qQNaN(),lon=qQNaN(),yaw=qQNaN(),pitch=qQNaN(),roll=qQNaN();
    int accepted=0,located=0,depths=0;
    QJsonArray displayColumns;
    QFile points("kogger-bottom-track.csv");require(points.open(QIODevice::WriteOnly),"cannot save bottom-track evidence");
    points.write("epoch,latitude,longitude,depth_m\n");
    const auto sampleConnection=QObject::connect(&service,&NavoKoggerService::bottomSampleReady,
        [&](int epoch,double la,double lo,double depth,double){
            require(std::isfinite(la)&&std::isfinite(lo)&&depth>0&&depth<50,"invalid processed georeferenced depth");++depths;
            points.write(QString("%1,%2,%3,%4\n").arg(epoch).arg(la,0,'f',7).arg(lo,0,'f',7).arg(depth,0,'f',3).toUtf8());
        });
    QObject::connect(&decoder,&NavoKoggerDecoder::chartColumnReady,[&]{
        require(decoder.chartAddress()==2,"recording route was not preserved");
        if(accepted>=2000 && displayColumns.size()<240){
            QJsonArray samples;for(const char byte:decoder.chartRawBytes())samples.append(double(quint8(byte))/255.0);
            displayColumns.append(QJsonObject{{"samples",samples},{"offset",decoder.chartOffsetMeters()},
                {"range",decoder.chartRangeMeters()},{"bottom",QJsonValue::Null}});
        }
        NavoKoggerDatasetAdapter adapter;
        require(adapter.append(decoder,lat,lon,0),"recorded pipeline adapter failed");
        if(service.ingest(adapter.records().last(),channel,yaw,pitch,roll)){
            ++accepted;if(adapter.records().last().hasPosition())++located;
        }
    });
    // The fixture includes original MAVLink inside KP2 proxy packets. Read its
    // actual GPS/attitude, never invent a track for the DownView recording.
    Parsers::FrameParser parser;
    QByteArray mutableBytes=bytes;
    parser.setContext(reinterpret_cast<uint8_t*>(mutableBytes.data()),mutableBytes.size());
    int frames=0;
    while(parser.availContext()>0){
        parser.process();
        if(parser.completeAsKBP2())decoder.feedBytes(QByteArray(reinterpret_cast<const char*>(parser.frame()),parser.frameLen()));
        else if(parser.isCompleteAsMAVLink()){
            auto& mav=static_cast<Parsers::ProtoMAVLink&>(parser);
            const auto* raw=parser.frame();const int header=parser.proto()==Parsers::FrameParser::ProtoMAVLink2?10:6;
            const auto* payload=raw+header;const int length=raw[1];
            if(mav.msgId()==33 && length>=28){
                lat=double(qFromLittleEndian<qint32>(payload+4))*1e-7;
                lon=double(qFromLittleEndian<qint32>(payload+8))*1e-7;
                const auto heading=qFromLittleEndian<quint16>(payload+26);
                if(heading!=65535)yaw=double(heading)*0.01;
            }else if(mav.msgId()==30 && length>=16){
                float values[3];for(int i=0;i<3;++i){const quint32 bits=qFromLittleEndian<quint32>(payload+4+i*4);std::memcpy(&values[i],&bits,4);}
                roll=values[0]*180.0/M_PI;pitch=values[1]*180.0/M_PI;yaw=values[2]*180.0/M_PI;
            }
        }
        if((++frames%1024)==0)QCoreApplication::processEvents(QEventLoop::AllEvents,1);
        if(service.capacityFull()){
            QElapsedTimer drain;drain.start();
            while(service.capacityFull() && drain.elapsed()<10000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
            require(!service.capacityFull(),"rolling Dataset did not drain its previous batch");
        }
    }
    require(accepted==15423 && service.dataset().size()<=3000,"rolling Dataset lost columns or exceeded its budget");
    require(located>15000,"fixture MAVLink GPS was not paired with CHART");
    QElapsedTimer timeout;timeout.start();
    while(timeout.elapsed()<30000 && service.processedColumns()<14000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    require(service.processedColumns()>14000 && service.processedColumns()<=accepted,"original bottom-track processor did not return located depths");
    require(std::isfinite(service.bottomDepth()) && service.bottomDepth()>0,"no processed bottom depth");
    float minN=INFINITY,minE=INFINITY,maxN=-INFINITY,maxE=-INFINITY;
    for(int i=0;i<service.dataset().size();++i){
        const auto position=service.dataset().fromIndexCopy(i).getSonarPosition();
        if(!position.ned.isCoordinatesValid())continue;
        minN=std::min(minN,float(position.ned.n));maxN=std::max(maxN,float(position.ned.n));
        minE=std::min(minE,float(position.ned.e));maxE=std::max(maxE,float(position.ned.e));
    }
    require(std::isfinite(minN),"no located sonar positions for bathymetry");
    std::cout<<"Surface viewport N="<<minN<<":"<<maxN<<" E="<<minE<<":"<<maxE<<std::endl;
    QObject::connect(&service.processor(),&DataProcessor::pipelineStats,[](const QVariantMap& stats){
        std::cout<<"Surface diagnostics: "<<QJsonDocument(QJsonObject::fromVariantMap(stats)).toJson(QJsonDocument::Compact).constData()<<std::endl;
    });
    service.requestVisibleRect(minN-20,minE-20,maxN+20,maxE+20);
    timeout.restart();while(timeout.elapsed()<5000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    service.processor().requestPipelineStats();
    timeout.restart();while(timeout.elapsed()<1000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    require(service.tileCount()>0,"surface processor returned no bathymetry tiles for the recorded track");
    std::cout<<"PASS native processors: "<<accepted<<" recorded epochs, "<<located<<" with original GPS, "<<depths
             <<" processed depth updates, "<<service.tileCount()<<" visible bathymetry tiles\n";
    QFile display("kogger-columns.json");require(display.open(QIODevice::WriteOnly),"cannot save visual fixture");
    display.write(QJsonDocument(displayColumns).toJson(QJsonDocument::Compact));
    points.close();
    QObject::disconnect(sampleConnection);
    service.clear();
}
int main(int argc,char**argv) {
    qputenv("QT_QPA_PLATFORM","offscreen");
    QGuiApplication app(argc,argv);
    try {
        synthetic();
        if(argc==2) {
            QFile file(QString::fromLocal8Bit(argv[1])); require(file.open(QIODevice::ReadOnly),"cannot open KLF");
            const QByteArray bytes=file.readAll();
            require(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex()==
                "1ff5e23abbdd37e31eeacd7875c4e8a457ccb927641e47ea77c861151ab2ace0","fixture hash mismatch");
            const Result whole=replay(bytes,false), split=replay(bytes,true);
            require(whole.columns==15423 && split.columns==whole.columns,"recorded column count mismatch");
            require(whole.hash=="f597aee532fadf5ec71e48b4fd2f8890ee32c63927023e66d15516dfef745055" && split.hash==whole.hash,
                "recorded CHART bytes differ from fixture reference");
            std::cout<<"PASS KLF: "<<whole.columns<<" completed columns, 5000 samples, 10 mm, byte-identical chunked replay, Dataset/Epoch ingestion and bounded adapter retention\n";
            recordedProcessors(bytes);
            std::cout<<"Trailing 200-sample column remains pending; live decoding needs the next column boundary.\n";
        }
        if(argc==2)NavoKoggerService::instance().shutdown();
    }catch(const std::exception& e){
        if(argc==2)NavoKoggerService::instance().shutdown();
        std::cerr<<e.what()<<'\n';return 1;
    }
}
