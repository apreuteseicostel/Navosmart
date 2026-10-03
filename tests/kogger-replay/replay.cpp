#include "../../custom/src/NavoKoggerDecoder.h"
#include "../../custom/src/NavoKoggerReplay.h"
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QTemporaryDir>
#include <QSettings>
#include "../../custom/src/NavoPersistence.h"
#include <QQmlComponent>
#include <QFileInfo>
#include <QTcpServer>
#include "../../custom/src/NavoEthernetTransport.h"
#include "../../custom/src/NavoKoggerChartBridge.h"
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

static QVariantList recordedGeoSamples;
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
    bool gpsFix=false;
    int accepted=0,located=0,depths=0,geosamples=0;
    QHash<quint64,qint64> arrivalTimes;
    QSet<quint64> emittedSequences;
    const auto geoConnection=QObject::connect(&service,&NavoKoggerService::geoSampleReady,[&](const QVariantMap& sample){
        const auto sequence=sample.value("sequence").toULongLong();
        require(arrivalTimes.contains(sequence) && sample.value("time").toLongLong()==arrivalTimes.value(sequence),"processed sample lost original column arrival time");
        require(!emittedSequences.contains(sequence),"position refresh duplicated a processed geo sample");
        require(sample.value("chartResolution").toInt()==10 && std::abs(sample.value("chartRangeMeters").toDouble()-50)<1e-6,"processed geo sample lost its physical scale");
        require(std::isfinite(sample.value("bottomEcho").toDouble()),"processed sample lost its own bottom echo");
        emittedSequences.insert(sequence);recordedGeoSamples.append(sample);++geosamples;
    });
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
        require(adapter.append(decoder,lat,lon,100000+accepted),"recorded pipeline adapter failed");
        arrivalTimes.insert(decoder.chartSequence(),100000+accepted);
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
            if(mav.msgId()==24 && length>=30){
                gpsFix=payload[28]>=3;
                lat=gpsFix?double(qFromLittleEndian<qint32>(payload+8))*1e-7:qQNaN();
                lon=gpsFix?double(qFromLittleEndian<qint32>(payload+12))*1e-7:qQNaN();
            }else if(mav.msgId()==33 && length>=28 && gpsFix){
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
    require(service.dataset().getLlaRef().isInit && std::abs(service.dataset().getLlaRef().refLla.latitude-40.16)<0.01,"invalid GPS initialized the local bathymetry origin");
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
    require(std::isfinite(minN) && std::abs(minN)<5000 && std::abs(maxN)<5000 && std::abs(minE)<5000 && std::abs(maxE)<5000,"no located sonar positions for bathymetry");
    std::cout<<"Surface viewport N="<<minN<<":"<<maxN<<" E="<<minE<<":"<<maxE<<std::endl;
    QObject::connect(&service.processor(),&DataProcessor::pipelineStats,[](const QVariantMap& stats){
        std::cout<<"Surface diagnostics: "<<QJsonDocument(QJsonObject::fromVariantMap(stats)).toJson(QJsonDocument::Compact).constData()<<std::endl;
    });
    service.requestVisibleRect(minN-20,minE-20,maxN+20,maxE+20);
    timeout.restart();while(timeout.elapsed()<5000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    service.processor().requestPipelineStats();
    timeout.restart();while(timeout.elapsed()<1000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    require(service.tileCount()>0,"surface processor returned no bathymetry tiles for the recorded track");
    QFile cells("kogger-bathymetry-cells.csv");require(cells.open(QIODevice::WriteOnly),"cannot save surface evidence");
    cells.write("north_m,east_m,depth_m,height_type\n");
    int surfaceCells=0,triangulated=0;
    for(const auto& tile:service.tiles()){
        const auto& vertices=tile.getHeightVerticesCRef();const auto& marks=tile.getHeightMarkVerticesCRef();
        require(vertices.size()==marks.size(),"surface height marks do not match vertices");
        for(int i=0;i<vertices.size();++i){
            if(marks[i]==HeightType::kUndefined)continue;
            const auto& point=vertices[i];const double depth=-point.z();
            require(std::isfinite(depth)&&depth>0&&depth<50,"invalid native bathymetry cell depth");
            cells.write(QString("%1,%2,%3,%4\n").arg(point.x(),0,'f',3).arg(point.y(),0,'f',3).arg(depth,0,'f',3).arg(int(marks[i])).toUtf8());
            ++surfaceCells;if(marks[i]==HeightType::kTriangulation)++triangulated;
        }
    }
    require(surfaceCells>0 && triangulated>0,"native tiles contain no triangulated depth cells");
    cells.close();
    std::cout<<"PASS surface height evidence: "<<surfaceCells<<" cells, "<<triangulated<<" triangulated cells\n";
    std::cout<<"PASS native processors: "<<accepted<<" recorded epochs, "<<located<<" with original GPS, "<<depths
             <<" processed depth updates, "<<service.tileCount()<<" visible bathymetry tiles\n";
    QFile display("kogger-columns.json");require(display.open(QIODevice::WriteOnly),"cannot save visual fixture");
    display.write(QJsonDocument(displayColumns).toJson(QJsonDocument::Compact));
    points.close();
    require(geosamples>14000,"processed column metadata was not published");
    QObject::disconnect(sampleConnection);
    QObject::disconnect(geoConnection);
    service.clear();
}
static void qmlBathymetryPipeline(const QString& directory,const QVariantList& samples) {
    require(samples.size()>14000,"recorded bathymetry samples missing");
    QQmlEngine engine;
    const auto load=[&](const QString& name){
        QQmlComponent component(&engine,QUrl::fromLocalFile(directory+"/"+name));
        if(component.isError())std::cerr<<component.errorString().toStdString();
        auto object=std::unique_ptr<QObject>(component.create());require(bool(object),"production bathymetry QML failed to load");return object;
    };
    auto mapping=load("NavoSonarMapping.qml");
    mapping->setProperty("scanning",true);mapping->setProperty("sonarConnected",true);mapping->setProperty("externalSampleIngestion",true);
    for(const auto& sample:samples)require(QMetaObject::invokeMethod(mapping.get(),"ingestSample",Q_ARG(QVariant,sample)),"mapping did not accept native sample");
    const auto mapped=mapping->property("rawSamples").toList();
    require(mapped.size()==samples.size(),"production mapping lost processed samples");
    require(mapped.last().toMap().value("sequence").toULongLong()==samples.last().toMap().value("sequence").toULongLong(),"mapping lost column identity");
    auto model=load("NavoBathymetryModel.qml");
    require(QMetaObject::invokeMethod(model.get(),"rebuild",Q_ARG(QVariant,QVariant(mapped))),"cannot rebuild production bathymetry grid");
    const auto cells=model->property("cells").toList();require(cells.size()>3,"production bathymetry grid is empty");
    auto hd=load("NavoBathymetryHDModel.qml");hd->setProperty("sourceCells",cells);
    require(QMetaObject::invokeMethod(hd.get(),"rebuild"),"cannot rebuild HD interpolation");
    const auto grid=hd->property("gridCells").toList();const auto contours=hd->property("contourSegments").toList();
    require(hd->property("ready").toBool() && !grid.isEmpty() && !contours.isEmpty(),"production HD bathymetry/contours are empty");
    for(const auto& cell:cells){const auto depth=cell.toMap().value("depth").toDouble();require(std::isfinite(depth)&&depth>0&&depth<50,"invalid mapped bathymetry depth");}
    QTemporaryDir settings;require(settings.isValid(),"cannot isolate persistence settings");
    QCoreApplication::setOrganizationName("NavoRecordedReplay");QCoreApplication::setApplicationName("BathymetryValidation");
    QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,settings.path());
    {NavoPersistence persistence;for(const auto& sample:mapped)persistence.addSonarSample(sample.toMap());}
    NavoPersistence restored;const auto loaded=restored.sonarSamples();require(loaded.size()==mapped.size(),"persistence did not restore recorded sample count");
    for(int i=0;i<loaded.size();++i){
        const auto a=mapped[i].toMap(),b=loaded[i].toMap();
        for(const char* field:{"lat","lon","depth","time","sequence","chartResolution","chartRangeMeters"})
            require(std::abs(a.value(field).toDouble()-b.value(field).toDouble())<1e-9,"persistence changed georeferenced column metadata");
    }
    std::cout<<"PASS production mapping -> persistence reload -> bathymetry/HD: "<<mapped.size()<<" samples, "<<cells.size()<<" grid cells, "<<grid.size()<<" HD cells, "<<contours.size()<<" contour segments\n";
}

static void qmlTransportRoundTrip(const QString& source) {
    qmlRegisterType<NavoKoggerReplay>("NavoSmart.Backend",1,0,"NavoKoggerReplay");
    qmlRegisterType<NavoKoggerDecoder>("NavoSmart.Backend",1,0,"NavoKoggerDecoder");
    qmlRegisterType<NavoKoggerChartBridge>("NavoSmart.Backend",1,0,"NavoKoggerChartBridge");
    qmlRegisterType<NavoEthernetTransport>("NavoSmart.Backend",1,0,"NavoEthernetTransport");
    QQmlEngine engine;
    QQmlComponent vehicleComponent(&engine);
    vehicleComponent.setData(R"(import QtQuick
QtObject {
 property QtObject coordinate: QtObject {property bool isValid:true;property real latitude:40.1616;property real longitude:44.4743}
 property QtObject gps: QtObject {property QtObject lock: QtObject {property int rawValue:0}}
 property QtObject vehicleLinkManager: QtObject {property bool communicationLost:false}
 property QtObject heading: QtObject {property real rawValue:12}
 property QtObject pitch: QtObject {property real rawValue:0}
 property QtObject roll: QtObject {property real rawValue:0}
})",QUrl());
    std::unique_ptr<QObject> vehicle(vehicleComponent.create());require(bool(vehicle),"GPS fixture QML failed to load");
    QQmlComponent component(&engine,QUrl::fromLocalFile(QFileInfo(source).absoluteFilePath()));
    if(component.isError())std::cerr<<component.errorString().toStdString();
    std::unique_ptr<QObject> sonar(component.create());require(bool(sonar),"production SonarEthernet QML failed to load");
    sonar->setProperty("autoReconnect",false);sonar->setProperty("vehicle",QVariant::fromValue(vehicle.get()));
    QTcpServer server;require(server.listen(QHostAddress::LocalHost),"local sonar TCP source failed to listen");
    sonar->setProperty("host",QStringLiteral("127.0.0.1"));sonar->setProperty("port",server.serverPort());
    require(QMetaObject::invokeMethod(sonar.get(),"connectSonar"),"cannot connect production sonar transport");
    auto wait=[&](auto ready){QElapsedTimer timer;timer.start();while(!ready()&&timer.elapsed()<3000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}return ready();};
    require(wait([&]{return server.hasPendingConnections();}),"production sonar did not establish TCP");
    std::unique_ptr<QTcpSocket> socket(server.nextPendingConnection());
    const auto send=[&]{socket->write(frame(false,0,QByteArray(32,char(90))));socket->flush();};
    send();send();
    require(wait([&]{return sonar->property("nativeChartRecords").toInt()>=1;}),"TCP CHART did not reach production bridge");
    require(sonar->property("dataAlive").toBool() && sonar->property("echoFresh").toBool(),"CHART-only TCP heartbeat is not live");
    require(sonar->property("chartRawByteCount").toInt()==32,"production QML lost raw byte count");
    auto& service=NavoKoggerService::instance();
    require(!service.dataset().getLlaRef().isInit,"QML accepted a coordinate without GPS fix");
    auto* gps=vehicle->property("gps").value<QObject*>();auto* lock=gps->property("lock").value<QObject*>();lock->setProperty("rawValue",3);
    send();
    require(wait([&]{return sonar->property("nativeChartRecords").toInt()>=2;}),"located column did not reach bridge");
    require(service.dataset().getLlaRef().isInit && std::abs(service.dataset().getLlaRef().refLla.latitude-40.1616)<1e-6,"QML did not establish origin after GPS fix");
    lock->setProperty("rawValue",1);send();
    require(wait([&]{return sonar->property("nativeChartRecords").toInt()>=3;}),"GPS-loss column did not reach bridge");
    require(!service.dataset().fromIndexCopy(service.dataset().endIndex()).getPositionGNSS().lla.isCoordinatesValid(),"QML retained located samples after GPS fix loss");
    require(QMetaObject::invokeMethod(sonar.get(),"disconnectSonar"),"cannot disconnect production transport");
    require(!sonar->property("dataAlive").toBool(),"sonar heartbeat remained live after disconnect");
    service.clear();
    std::cout<<"PASS production SonarEthernet QML: real localhost TCP -> decoder -> channel bridge -> Dataset, CHART-only heartbeat and GPS fix/loss gating\n";
}

static void qmlRecordedReplay(const QString& source,const QString& fixture) {
    QQmlEngine engine;
    QQmlComponent component(&engine,QUrl::fromLocalFile(QFileInfo(source).absoluteFilePath()));
    if(component.isError())std::cerr<<component.errorString().toStdString();
    std::unique_ptr<QObject> sonar(component.create());
    require(bool(sonar),"production replay QML failed to load");
    sonar->setProperty("autoReconnect",false);
    QVariant opened;
    require(QMetaObject::invokeMethod(sonar.get(),"startReplay",Q_RETURN_ARG(QVariant,opened),
        Q_ARG(QVariant,QVariant(QUrl::fromLocalFile(QFileInfo(fixture).absoluteFilePath())))) && opened.toBool(),"cannot start actual file replay");
    auto* replay=qobject_cast<NavoKoggerReplay*>(sonar->property("replay").value<QObject*>());
    require(replay,"actual replay object missing");
    QVariantList samples;
    auto* bridge=qobject_cast<NavoKoggerChartBridge*>(sonar->property("nativeBridge").value<QObject*>());
    require(bridge,"actual replay bridge missing");
    // Capture only the real QML-published signal, including replay tagging.
    engine.rootContext()->setContextProperty("replaySource",sonar.get());
    QQmlComponent sinkComponent(&engine);
    sinkComponent.setData(R"(import QtQuick
QtObject {
 id: sink
 property var samples: []
 property Connections connection: Connections {
  target: replaySource
  function onGeoSample(sample) { var copy=sink.samples.slice();copy.push(sample);sink.samples=copy }
 }
})",QUrl());
    std::unique_ptr<QObject> sink(sinkComponent.create());
    require(bool(sink),"replay signal sink failed to load");

    replay->setPaused(true);const auto before=replay->position();
    require(QMetaObject::invokeMethod(replay,"tick"),"replay pump missing");
    require(replay->position()==before,"paused replay advanced");
    replay->setPaused(false);
    QElapsedTimer timer;timer.start();
    while(replay->active() && timer.elapsed()<180000) {
        require(QMetaObject::invokeMethod(replay,"tick"),"cannot pump production replay");
        QCoreApplication::processEvents(QEventLoop::AllEvents,5);
    }
    require(!replay->active(),"actual replay did not reach EOF");
    auto& service=NavoKoggerService::instance();
    timer.restart();
    while(service.processedColumns()<14000 && timer.elapsed()<30000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    samples=sink->property("samples").toList();
    std::cout<<"Replay diagnostics: processed="<<service.processedColumns()<<", samples="<<samples.size()<<", records="<<bridge->datasetColumns()<<", unlocated="<<bridge->unlocatedColumns()<<std::endl;
    require(service.processedColumns()>14000 && samples.size()>14000,"actual QML replay failed to publish located bottom samples");
    require(sonar->property("nativeChannelReady").toBool(),"replay native channel disabled");
    require(!sonar->property("dataAlive").toBool(),"replay claimed live telemetry");
    for(const auto& sample:samples) {
        const auto s=sample.toMap();
        require(s.value("replay").toBool(),"QML replay sample not tagged");
        require(std::abs(s.value("lat").toDouble()-40.16)<0.01,"replay GPS differs from recorded track");
    }
    bridge->requestReplaySurface();
    timer.restart();while(timer.elapsed()<6000){QCoreApplication::processEvents(QEventLoop::AllEvents,20);QThread::msleep(1);}
    require(service.tileCount()>0,"actual file replay generated no native surface tiles");
    qmlBathymetryPipeline(QFileInfo(source).absolutePath(),samples);
    require(QMetaObject::invokeMethod(sonar.get(),"stopReplay"),"cannot stop actual replay");
    require(!sonar->property("replayMode").toBool() && service.dataset().size()==0,"explicit replay stop retained native session");
    std::cout<<"PASS actual file replay -> recorded GPS -> production QML bridge -> native bottom/tiles -> mapping/persistence/HD; pause, EOF and stop\n";
}

int main(int argc,char**argv) {
    qputenv("QT_QPA_PLATFORM","offscreen");
    QGuiApplication app(argc,argv);
    try {
        if(argc==3 && QString::fromLocal8Bit(argv[1])==QStringLiteral("--transport")){
            qmlTransportRoundTrip(QString::fromLocal8Bit(argv[2]));NavoKoggerService::instance().shutdown();return 0;
        }
        synthetic();
        if(argc>=2) {
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
            if(argc>=3){
                qmlBathymetryPipeline(QFileInfo(QString::fromLocal8Bit(argv[2])).absolutePath(),recordedGeoSamples);
                qmlTransportRoundTrip(QString::fromLocal8Bit(argv[2]));
                qmlRecordedReplay(QString::fromLocal8Bit(argv[2]),QString::fromLocal8Bit(argv[1]));
            }
            std::cout<<"Trailing 200-sample column remains pending; live decoding needs the next column boundary.\n";
        }
        if(argc>=2)NavoKoggerService::instance().shutdown();
    }catch(const std::exception& e){
        if(argc>=2)NavoKoggerService::instance().shutdown();
        std::cerr<<e.what()<<'\n';return 1;
    }
}
