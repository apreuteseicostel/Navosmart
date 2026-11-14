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
 // Kogger-style file browsing is read-only: FULL overview and backward/forward
 // detail return real CHART bytes without moving the playback QFile.
 replay.setPaused(true);
 const qint64 playbackPosBeforeBrowse=replay.position();
 const int overviewWidth=fixture?64:42;
 auto whole=replay.readDisplaySlice(count-1,count,overviewWidth,0,overviewWidth);
 require(whole.size()==overviewWidth,"full-file overview did not cover screen width");
 require(whole.front().sourceIndex==0,"full-file overview does not begin at first column");
 require(whole.back().sourceIndex<count && whole.back().sourceIndex>=count-2-count/overviewWidth,
         "full-file overview omits the final part of recording");
 const auto midWindow=replay.readDisplaySlice(count/2,fixture?40:10,10,0,10);
 require(midWindow.size()==10,"detail view missing some historical columns");
 require(midWindow.front().sourceIndex<count/2,"detail does not show columns before cursor");
 const auto firstWindow=replay.readDisplaySlice(count-1,fixture?40:10,10,0,10);
 require(firstWindow.size()==10,"last columns not available after backward browse");
 const auto backwards=replay.readDisplaySlice(fixture?100:12,fixture?40:10,10,0,10);
 require(backwards.size()==10,"backwards browse failed");
 require(replay.position()==playbackPosBeforeBrowse && replay.paused(),
         "visual browse rewound or restarted the playback reader");
 if(!fixture) {
  for(int x=0;x<42;++x){
   require(!whole[x].bytes.isEmpty(),"indexed CHART column missing from overview");
   require(whole[x].sourceIndex==x,"overview column global index mismatch");
   require(quint8(whole[x].bytes[0])==20+x,"overview did not decode original CHART amplitude");
  }
  require(quint8(backwards[0].bytes[0])==20+backwards[0].sourceIndex,
          "backward browsing changed actual source sample");
 }
 replay.setPaused(false);
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
