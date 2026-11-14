#include "../../custom/src/NavoKoggerReplay.h"
#include "../../custom/src/NavoKoggerDecoder.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QFile>
#include <QElapsedTimer>
#include <QThread>
#include <QUrl>
#include <QtEndian>
#include <cmath>
#include <cstdlib>
#include <iostream>
static void require(bool yes,const char*why) {
 if(!yes){std::cerr<<"FAIL: "<<why<<"\n";std::exit(1);}
}
static QByteArray kp1(quint16 sequence,quint8 amplitude) {
 QByteArray f;
 f.append(char(0xbb));f.append(char(0x55));
 f.append(char(1));f.append(char(1));f.append(char(3));
 f.append(char(7)); // 6-byte CHART fragment header + one sample
 auto push16=[&](quint16 n){f.append(char(n&255));f.append(char(n>>8));};
 push16(sequence);push16(100);push16(0);f.append(char(amplitude));
 quint8 a=0,b=0;
 for(int i=2;i<f.size();i++){a=quint8(a+quint8(f.at(i)));b=quint8(b+a);}
 f.append(char(a));f.append(char(b));
 return f;
}
static void drain(NavoKoggerReplay& r,const int& published,int maxMs=5000){
 QElapsedTimer t;t.start();
 while(r.active() && !r.paused() && published<3 && t.elapsed()<maxMs){
  QCoreApplication::processEvents(QEventLoop::AllEvents,20);
  QMetaObject::invokeMethod(&r,"tick");
 }
}
static bool indexed(NavoKoggerReplay& r,int timeout=45000){
 QElapsedTimer t;t.start();
 while(!r.indexReady() && t.elapsed()<timeout){
  QCoreApplication::processEvents(QEventLoop::AllEvents,10);
  QThread::msleep(3);
 }
 return r.indexReady();
}
int main(int argc,char**argv){
 QCoreApplication app(argc,argv);
 const bool fixture=argc>1;
 QTemporaryDir dir;
 require(dir.isValid(),"temporary dir");
 QString filePath=fixture?QString::fromLocal8Bit(argv[1]):dir.filePath("index.klf");
 QByteArray original;
 if(!fixture){
  original.append(QByteArray("not an actual frame",19));
  for(int i=0;i<42;i++){
   original.append(kp1(0,quint8(20+i)));
   original.append(kp1(1,quint8(20+i)));
   original.append(QByteArray("x",1));
  }
  QFile out(filePath);require(out.open(QIODevice::WriteOnly),"open fixture");
  require(out.write(original)==original.size(),"write fixture");
 }
 NavoKoggerReplay replay;
 NavoKoggerDecoder decoder;
 int published=0;double firstAmplitude=-1;
 double firstSeekLatitude=qQNaN(),firstSeekLongitude=qQNaN();
 QObject::connect(&replay,&NavoKoggerReplay::positionReady,[&](double lat,double lon,double,double,double){
  if(!std::isfinite(firstSeekLatitude)&&std::isfinite(lat)&&std::isfinite(lon)){
   firstSeekLatitude=lat;firstSeekLongitude=lon;
  }
 });
 QObject::connect(&replay,&NavoKoggerReplay::bytesReady,&decoder,&NavoKoggerDecoder::feedBytes);
 QObject::connect(&replay,&NavoKoggerReplay::previewLastColumnReady,&decoder,&NavoKoggerDecoder::flushPendingChart);
 QObject::connect(&decoder,&NavoKoggerDecoder::chartColumnReady,[&](){
  if(published==0 && decoder.chartRawByteCount()>0)firstAmplitude=double(quint8(decoder.chartRawBytes().at(0)));
  published++;
 });
 require(replay.open(QUrl::fromLocalFile(filePath)),"open klf");
 require(indexed(replay),"column index never completed");
 require(std::abs(replay.indexProgress()-1)<1e-9,"index progress not complete");
 const int count=replay.indexedColumns();
 if(fixture)require(count>=14000 && count<=20000,"real Kogger fixture index should cover all real columns");
 else require(count==42,"each physical CHART column indexed exactly once");
 require(!replay.seekColumn(-1) && !replay.seekColumn(count),"invalid seek accepted");
 const int wanted=fixture?count/2:19;
 decoder.reset();published=0;firstAmplitude=-1;
 firstSeekLatitude=qQNaN();firstSeekLongitude=qQNaN();
 require(replay.seekColumn(wanted),"direct seek to middle failed");
 require(replay.currentColumn()>=wanted,"file did not reposition to the selected CHART column");
 drain(replay,published);
 require(published>0,"seek did not decode the chosen column");
 if(fixture)require(std::isfinite(firstSeekLatitude)&&
   std::abs(firstSeekLatitude-40.16)<.02&&std::abs(firstSeekLongitude-44.47)<.02,
   "direct seek did not restore the recorded GPS context");
 if(!fixture)require(std::abs(firstAmplitude-(20+wanted))<1e-9,
                     "seek decoded wrong column or replayed from file beginning");
 decoder.reset();published=0;firstAmplitude=-1;
 require(replay.seekColumn(0),"return to first indexed column");
 drain(replay,published);
 require(published>0,"replay from zero produced no CHART column");
 if(!fixture)require(std::abs(firstAmplitude-20)<1e-9,"return to first column wrong");
 // A paused slider drag must show the chosen column then remain paused.
 require(replay.seekColumn(5),"prime a running replay before pausing");
 replay.setPaused(true);
 decoder.reset();published=0;firstAmplitude=-1;
 require(replay.seekColumn(wanted),"paused seek rejected");
 drain(replay,published);
 require(replay.paused() && published>0,"paused seek did not produce an inspectable column");
 if(!fixture)require(std::abs(firstAmplitude-(20+wanted))<1e-9,
                     "paused seek displayed wrong column");
 decoder.reset();published=0;firstAmplitude=-1;
 require(replay.seekColumn(count-1),"last indexed column seek failed");
 drain(replay,published);
 require(replay.paused()&&published>0,"final KLF column did not flush on paused preview");
 if(!fixture)require(std::abs(firstAmplitude-(20+count-1))<1e-9,
                     "last column preview is not the selected last column");
 if(!fixture){
  QFile stored(filePath);require(stored.open(QIODevice::ReadOnly)&&stored.readAll()==original,
                          "index/seek modified original KLF");
 }
 std::cout<<"PASS KLF index and direct mid-file/first-column seek: "<<count
          <<" column offsets, decoded after seek without replay-from-zero\n";
}
