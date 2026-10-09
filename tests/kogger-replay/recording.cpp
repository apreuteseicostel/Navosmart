#include "../../custom/src/NavoKoggerRecorder.h"
#include "../../custom/src/NavoKoggerReplay.h"
#include <QCoreApplication>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QThread>
#include <QDir>
#include <iostream>
#include <cstdlib>

static void require(bool ok,const char* message) { if(!ok){std::cerr<<message<<'\n';std::exit(1);} }
int main(int argc,char** argv) {
 QTemporaryDir home; require(home.isValid(),"temporary home");
 qputenv("XDG_DATA_HOME",home.path().toUtf8());
 QCoreApplication app(argc,argv);app.setOrganizationName("NAVO-test");app.setApplicationName("recording");
 NavoKoggerRecorder recorder;
 require(recorder.start("  Balta / nord  "),"start");require(!recorder.start("second"),"reject duplicate start");
 const QByteArray first("\0\1\2\xff",4),second(150000,'\x7e');
 recorder.append(first,44.5,26.1,90,1,2);
 QThread::msleep(90);
 recorder.append(second,qQNaN(),qQNaN(),qQNaN(),qQNaN(),qQNaN());
 require(recorder.bytes()==first.size()+second.size(),"all raw bytes counted");
 require(recorder.sessions().isEmpty(),"unfinished recording hidden");
 require(recorder.stop(),"atomic commit");require(!recorder.recording(),"stopped");
 require(recorder.sessions().size()==1,"catalog entry");
 const auto entry=recorder.sessions().first().toMap();const auto url=entry.value("url").toUrl();
 require(entry.value("name").toString()=="Balta / nord","name does not become filesystem path");
 NavoKoggerRecorder restarted;require(restarted.sessions().size()==1,"catalog survives restart");
 NavoKoggerReplay replay; QByteArray received; int poses=0; bool invalidFix=false;
 QObject::connect(&replay,&NavoKoggerReplay::positionReady,[&](double lat,double lon,double heading,double,double){
  ++poses;if(poses==1)require(lat==44.5 && lon==26.1 && heading==90,"saved pose");else invalidFix=std::isnan(lat)&&std::isnan(lon);
 });
 QObject::connect(&replay,&NavoKoggerReplay::bytesReady,[&](const QByteArray& bytes){received+=bytes;});
 require(replay.open(url),"open offline archive");
 QThread::msleep(25);QMetaObject::invokeMethod(&replay,"tick");
 require(received==first,"timed playback does not release later chunks early");
 replay.setPaused(true);QThread::msleep(150);QMetaObject::invokeMethod(&replay,"tick");require(received==first,"pause");
 replay.setPaused(false);QThread::msleep(20);QMetaObject::invokeMethod(&replay,"tick");require(received==first,"pause time excluded");
 replay.setBlocked(true);QThread::msleep(150);QMetaObject::invokeMethod(&replay,"tick");require(received==first,"backpressure");
 replay.setBlocked(false);QThread::msleep(100);
 for(int i=0;i<10 && replay.active();++i)QMetaObject::invokeMethod(&replay,"tick");
 require(!replay.active() && replay.error().isEmpty(),"explicit EOF");
 require(received==first+second && poses==4 && invalidFix,"lossless chunks and GPS loss retained");
 require(recorder.start("empty"),"empty start");require(!recorder.stop(),"empty session rejected");require(recorder.sessions().size()==1,"no empty catalog entry");
 require(recorder.start("disconnected"),"new session");recorder.append(first,999,26,INFINITY,0,0);require(recorder.stop(),"sanitize invalid pose");
 const auto bad=home.path()+"/bad.navosonar";
 QFile original(url.toLocalFile());require(original.open(QIODevice::ReadOnly),"source open");auto data=original.readAll();
 auto write=[&](QByteArray contents){QFile file(bad);require(file.open(QIODevice::WriteOnly),"bad open");require(file.write(contents)==contents.size(),"bad write");};
 write(data.left(data.size()-2)); require(replay.open(QUrl::fromLocalFile(bad)),"truncated stream opens header");replay.setSpeed(5);
 for(int i=0;i<20 && replay.active();++i){QThread::msleep(20);QMetaObject::invokeMethod(&replay,"tick");}
 require(!replay.active() && !replay.error().isEmpty(),"missing footer is reported");
 auto flipped=data;
 QFile headerReader(url.toLocalFile());require(headerReader.open(QIODevice::ReadOnly),"header for corruption");QJsonObject metadata;
 require(NavoSonarArchive::readHeader(headerReader,metadata),"valid header");
 flipped[headerReader.pos()+52] ^= 1;write(flipped);
 require(replay.open(QUrl::fromLocalFile(bad)),"flipped payload header");QMetaObject::invokeMethod(&replay,"tick");
 require(!replay.active() && !replay.error().isEmpty(),"payload checksum rejects bit flip");
 write("NAVOSONAR1\n\xff\xff\xff\xff");require(!replay.open(QUrl::fromLocalFile(bad)),"oversized metadata rejected");
 write("wrong format");require(!replay.open(QUrl::fromLocalFile(bad)),"NAVO extension cannot masquerade as KLF");
 // An oversized record is rejected before allocating its payload.
 QFile malformed(bad);require(malformed.open(QIODevice::WriteOnly),"malformed open");
 require(NavoSonarArchive::writeHeader(malformed,{{"version",1}}),"header");
 QDataStream stream(&malformed);NavoSonarArchive::configure(stream);stream<<quint32(0xffffffff);malformed.close();
 require(replay.open(QUrl::fromLocalFile(bad)),"record header accepted");QMetaObject::invokeMethod(&replay,"tick");
 require(!replay.active() && !replay.error().isEmpty(),"oversized record rejected");
 std::cout<<"PASS NAVO archive: lossless chunking, recorded pose, GPS loss, atomic catalog/restart, timed replay, pause/backpressure, empty/corrupt/oversized files\n";
}
