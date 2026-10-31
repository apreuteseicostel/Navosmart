#include "NavoLanDiagnostics.h"
#include <QCoreApplication>
#include <QTcpServer>
#include <QSettings>
#include <QTemporaryDir>
#include <QThread>
#include <QPointer>
#include <cassert>
#include <functional>
#include <iostream>
static bool wait(const std::function<bool()>& done,int ms=2500){
    QElapsedTimer t;t.start();
    while(!done() && t.elapsed()<ms){QCoreApplication::processEvents();QThread::msleep(5);}
    return done();
}
int main(int argc,char** argv){
    QCoreApplication app(argc,argv);QTemporaryDir folder;
    QCoreApplication::setOrganizationName("NavoLanTest");QCoreApplication::setApplicationName("PassiveUart");
    QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,folder.path());
    QTcpServer web,uart;
    assert(web.listen(QHostAddress::LocalHost));assert(uart.listen(QHostAddress::LocalHost));
    QPointer<QTcpSocket> source;int clients=0;
    QObject::connect(&web,&QTcpServer::newConnection,&app,[&]{while(web.hasPendingConnections()){auto* c=web.nextPendingConnection();QObject::connect(c,&QTcpSocket::disconnected,c,&QObject::deleteLater);}});
    QObject::connect(&uart,&QTcpServer::newConnection,&app,[&]{source=uart.nextPendingConnection();++clients;});
    NavoLanDiagnostics d;assert(!d.online() && !d.uartConnected() && d.received()==0);
    d.setHost("8.8.8.8");d.setUartPort(int(uart.serverPort()));d.connectUart();assert(!d.uartConnected());
    d.setHost("127.0.0.1");d.setMonitorPort(int(web.serverPort()));d.setUartPort(int(uart.serverPort()));
    d.setBlocked({QVariantMap{{"host",d.host()},{"port",d.uartPort()}}});d.connectUart();assert(!d.uartConnected() && clients==0);
    d.setBlocked({});d.setMonitoring(true);assert(wait([&]{return d.online();}));
    d.connectUart();assert(wait([&]{return d.uartConnected() && source;}));
    assert(d.received()==0 && d.uartStatus().contains("UART neconfirmat"));
    source->write(QByteArray::fromHex("0041ff0a"));source->flush();assert(wait([&]{return d.received()==4;}));
    assert(d.preview().contains("00 41 ff 0a") && d.preview().contains(".A.."));
    assert(source->bytesAvailable()==0); // not even a probe/echo string goes to serial output
    source->write(QByteArray(10000,'X'));source->flush();assert(wait([&]{return d.received()==10004;}));
    assert(d.preview().size()<=4110);
    d.setBlocked({QVariantMap{{"host",d.host()},{"port",d.uartPort()}}});assert(!d.uartConnected());
    d.setBlocked({});d.stopUart();d.setMonitoring(false);assert(!d.online());
    d.connectUart();assert(wait([&]{return d.uartConnected() && clients==2;}));
    d.setSuspended(true);assert(!d.online() && !d.uartConnected());
    d.setSuspended(false);assert(!d.uartConnected()); // no serial auto-reconnect after replay
    d.setHost("192.168.255.254");assert(!d.online() && d.received()==0);
    d.setUartPort(d.monitorPort());d.connectUart();assert(!d.uartConnected());
    assert(!d.interfaces().isEmpty());
    std::cout<<"PASS actual Qt TCP: explicit witness, passive UART RX/HEX/text, zero TX, bounded preview, active-port exclusion, replay, endpoint reset, no serial auto-reconnect and invalid targets\n";
}
