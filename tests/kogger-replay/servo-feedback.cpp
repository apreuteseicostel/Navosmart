#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QFileInfo>
#include <iostream>
#include <stdexcept>
class FeedbackVehicle : public QObject {
    Q_OBJECT
    Q_PROPERTY(int id READ id CONSTANT)
public:
    int id() const {return 42;}
signals:
    void mavCommandResult(int vehicleId,int component,int command,int result,int failure);
};
static void check(bool ok,const char* msg){if(!ok)throw std::runtime_error(msg);}
int main(int argc,char**argv){
    qputenv("QT_QPA_PLATFORM","offscreen");QGuiApplication app(argc,argv);
    try {
        check(argc==2,"use: servo-feedback NavoHopperBridge.qml");
        QQmlEngine engine;FeedbackVehicle first,second;
        QQmlComponent component(&engine,QUrl::fromLocalFile(QFileInfo(QString::fromLocal8Bit(argv[1])).absoluteFilePath()));
        if(component.isError())std::cerr<<component.errorString().toStdString();
        std::unique_ptr<QObject> bridge(component.createWithInitialProperties({{"vehicle",QVariant::fromValue<QObject*>(&first)}}));
        check(bool(bridge),"production hopper bridge failed to load");
        const auto response=[&]{return bridge->property("servoResponse").toString();};
        first.mavCommandResult(43,1,183,0,0);check(bridge->property("servoResponseAtMs").toDouble()==0,"foreign vehicle ACK accepted");
        first.mavCommandResult(42,1,183,0,0);check(response().contains("acceptat"),"real Qt signal did not reach hopper bridge");
        check(!bridge->property("physicalPositionConfirmed").toBool() && !bridge->property("leftOpen").toBool(),"ACK invented physical movement");
        first.mavCommandResult(42,1,183,0,1);check(response().contains("timeout"),"timeout shown as success");
        first.mavCommandResult(42,1,183,0,2);check(response().contains("netrimis"),"duplicate failure hidden");
        bridge->setProperty("vehicle",QVariant::fromValue<QObject*>(&second));QCoreApplication::processEvents();
        check(bridge->property("servoResponseAtMs").toDouble()==0,"vehicle switch kept stale ACK");
        first.mavCommandResult(42,1,183,0,0);check(!response().contains("acceptat"),"disconnected vehicle still updates feedback");
        second.mavCommandResult(42,1,183,2,0);check(response().contains("respins"),"new vehicle rejection lost");
        std::cout<<"PASS production hopper QML signal wiring: filtering, accepted/rejected/timeout/duplicate results, vehicle switch, no physical confirmation. Mock vehicle; not HIL.\n";
    }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
#include "servo-feedback.moc"
