#include "../../custom/src/NavoKoggerReplay.h"
#include <QCoreApplication>
#include <QTemporaryFile>
#include <QThread>
#include <iostream>

int main(int argc,char** argv) {
    QCoreApplication app(argc,argv);
    QTemporaryFile input;
    if(!input.open() || input.write(QByteArray(1024*1024,'\0'))!=1024*1024)return 1;
    input.flush();NavoKoggerReplay replay;
    if(!replay.open(QUrl::fromLocalFile(input.fileName())))return 2;
    replay.setSpeed(5);
    QThread::msleep(180);QMetaObject::invokeMethod(&replay,"tick");
    if(replay.position()!=65536)return 3; // Delayed tick catches up within its bound.
    replay.setPaused(true);auto before=replay.position();
    QThread::msleep(180);QMetaObject::invokeMethod(&replay,"tick");
    if(replay.position()!=before)return 4;
    replay.setPaused(false);QMetaObject::invokeMethod(&replay,"tick");
    if(replay.position()-before!=20480)return 5; // No catch-up for time spent paused.
    replay.setBlocked(true);before=replay.position();
    QThread::msleep(180);QMetaObject::invokeMethod(&replay,"tick");
    if(replay.position()!=before)return 6;
    replay.setBlocked(false);QMetaObject::invokeMethod(&replay,"tick");
    if(replay.position()-before!=20480)return 7;
    replay.setSpeed(1);before=replay.position();QMetaObject::invokeMethod(&replay,"tick");
    if(replay.position()-before!=4096)return 8;
    replay.stop();std::cout<<"PASS elapsed replay pacing, bounded catch-up, pause/backpressure and nominal manual ticks\n";
}
