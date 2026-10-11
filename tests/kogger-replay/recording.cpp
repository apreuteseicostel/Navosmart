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
 NavoKoggerReplay replay; QByteArray received; int poses=0,deliveredFrames=0;
 QObject::connect(&replay,&NavoKoggerReplay::annotationAnchorChanged,[&]{if(replay.annotationAnchor().isEmpty())deliveredFrames=0;});
 bool invalidFix=false;
 QObject::connect(&replay,&NavoKoggerReplay::positionReady,[&](double lat,double lon,double heading,double,double){
  ++poses;if(poses==1)require(lat==44.5 && lon==26.1 && heading==90,"saved pose");else invalidFix=std::isnan(lat)&&std::isnan(lon);
 });
 QObject::connect(&replay,&NavoKoggerReplay::bytesReady,[&](const QByteArray& bytes){require(replay.annotationAnchor().value("frame").toLongLong()==++deliveredFrames,"anchor published before bytes, not progress notification");received+=bytes;});
 require(replay.open(url),"open offline archive");
 QThread::msleep(25);QMetaObject::invokeMethod(&replay,"tick");
 require(received==first,"timed playback does not release later chunks early");
 const auto anchor=replay.annotationAnchor();
 require(anchor.value("frame").toLongLong()==1 && anchor.value("milliseconds").toLongLong()>=0 && anchor.value("latitude").toDouble()==44.5,"delivered record anchor, not read-ahead pose");
 require(!replay.saveAnnotation(anchor,QString(1001,'x'),2,18),"reject overlong note");
 require(!replay.saveAnnotation({},"bad",2,18) && !replay.saveAnnotation(anchor,"   ",2,18),"reject blank/foreign anchor");
 require(replay.saveAnnotation(anchor,"Prag observat",2.4,18),"save note atomically");
 require(replay.annotations().size()==1,"note available");
 const auto noteId=replay.annotations().first().toMap().value("id").toString();
 NavoKoggerReplay notesRestart;require(notesRestart.open(url),"reopen annotated source");notesRestart.setPaused(true);
 require(notesRestart.annotations().size()==1 && notesRestart.annotations().first().toMap().value("text").toString()=="Prag observat","note survives restart");
 require(notesRestart.editAnnotation(noteId,"Ecou de verificat"),"edit note");
 require(notesRestart.removeAnnotation(noteId) && notesRestart.annotations().isEmpty(),"delete note");
 require(notesRestart.saveAnnotation(anchor,"foreign",2,18)==false,"no delivered frame in new reader yet");
 require(replay.editAnnotation(noteId,"Prag actualizat"),"keep original reader note");
 notesRestart.stop();require(notesRestart.annotations().isEmpty() && notesRestart.annotationAnchor().isEmpty(),"stop clears note context");
 replay.setPaused(true);QThread::msleep(150);QMetaObject::invokeMethod(&replay,"tick");require(received==first,"pause");
 replay.setPaused(false);QThread::msleep(20);QMetaObject::invokeMethod(&replay,"tick");require(received==first,"pause time excluded");
 replay.setBlocked(true);QThread::msleep(150);QMetaObject::invokeMethod(&replay,"tick");require(received==first,"backpressure");
 replay.setBlocked(false);QThread::msleep(100);
 for(int i=0;i<10 && replay.active();++i)QMetaObject::invokeMethod(&replay,"tick");
 require(!replay.active() && replay.error().isEmpty(),"explicit EOF");
 require(received==first+second && poses==4 && invalidFix,"lossless chunks and GPS loss retained");
 require(replay.annotationAnchor().value("latitude").isNull(),"GPS loss anchor never uses live GPS");
 require(replay.annotations().first().toMap().value("latitude").toDouble()==44.5,"saved note anchor stays frozen");
 NavoKoggerReplay persisted;require(persisted.open(url),"load final notes");persisted.setPaused(true);
 require(persisted.annotations().first().toMap().value("text").toString()=="Prag actualizat","edit persisted");
 const auto notesPath=QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/replay-annotations/"+anchor.value("source").toString()+".json";
 QFile notesFile(notesPath);require(notesFile.open(QIODevice::WriteOnly|QIODevice::Truncate),"corrupt notes fixture");notesFile.write("broken JSON");notesFile.close();
 NavoKoggerReplay corruptNotes;require(corruptNotes.open(url),"sonar still opens with corrupt notes");corruptNotes.setPaused(true);
 require(!corruptNotes.annotationError().isEmpty() && corruptNotes.annotations().isEmpty(),"corrupt notes surfaced");
 corruptNotes.setPaused(false);QThread::msleep(30);QMetaObject::invokeMethod(&corruptNotes,"tick");
 require(!corruptNotes.saveAnnotation(corruptNotes.annotationAnchor(),"overwrite",2,18),"corrupt file refuses new notes");
 require(!corruptNotes.editAnnotation(noteId,"overwrite"),"corrupt note file cannot be overwritten");
 require(notesFile.open(QIODevice::ReadOnly) && notesFile.readAll()=="broken JSON","corrupt bytes retained");notesFile.close();
 require(QFile::remove(notesPath) && QDir().mkdir(notesPath),"write failure directory fixture");
 require(!replay.editAnnotation(noteId,"cannot save") && replay.annotations().first().toMap().value("text").toString()=="Prag actualizat","write failure retains in-memory note");
 require(recorder.start("empty"),"empty start");require(!recorder.stop(),"empty session rejected");require(recorder.sessions().size()==1,"no empty catalog entry");
 require(recorder.start("disconnected"),"new session");recorder.append(first,999,26,INFINITY,0,0);require(recorder.stop(),"sanitize invalid pose");
 const auto otherUrl=recorder.sessions().first().toMap().value("url").toUrl();
 NavoKoggerReplay isolated;require(isolated.open(otherUrl) && isolated.annotations().isEmpty(),"notes isolated by source");isolated.stop();
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
 // KLF has frame ordinal but no invented NAVO reception clock or live GPS.
 const auto klfPath=home.path()+"/synthetic.klf";
 QByteArray frame=QByteArray::fromHex("bb550001030800000a0000001020");quint8 a=0,b=0;
 for(int i=2;i<frame.size();++i){a=quint8(a+quint8(frame[i]));b=quint8(b+a);}frame.append(char(a));frame.append(char(b));
 QFile klf(klfPath);require(klf.open(QIODevice::WriteOnly) && klf.write(frame)==frame.size(),"KLF fixture");klf.close();
 NavoKoggerReplay klfReplay;require(klfReplay.open(QUrl::fromLocalFile(klfPath)),"KLF opens");QMetaObject::invokeMethod(&klfReplay,"tick");
 auto klfAnchor=klfReplay.annotationAnchor();require(klfAnchor.value("frame").toLongLong()==1 && klfAnchor.value("milliseconds").toLongLong()==-1 && klfAnchor.value("latitude").isNull(),"KLF frame with unknown time/GPS");
 require(!klfReplay.saveAnnotation(anchor,"wrong source",2,18),"foreign source refused after delivery");
 require(klfReplay.saveAnnotation(klfAnchor,"Ecou KLF",qQNaN(),qQNaN()),"KLF note at EOF");
 NavoKoggerReplay klfRestart;require(klfRestart.open(QUrl::fromLocalFile(klfPath)) && klfRestart.annotations().size()==1,"KLF notes reopen");
 require(klf.open(QIODevice::ReadOnly) && klf.readAll()==frame,"original replay never modified");
 std::cout<<"PASS replay annotations: frozen delivered anchor, atomic save/restart/edit/delete, source isolation, GPS loss, corruption and write failure\n";
 std::cout<<"PASS NAVO archive: lossless chunking, recorded pose, GPS loss, atomic catalog/restart, timed replay, pause/backpressure, empty/corrupt/oversized files\n";
}
