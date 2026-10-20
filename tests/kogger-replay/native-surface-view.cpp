#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QFileInfo>
#include <QEventLoop>
#include <QTimer>
#include <iostream>
#include <stdexcept>
static void check(bool ok,const char* msg){if(!ok)throw std::runtime_error(msg);}
static void events(){QEventLoop loop;QTimer::singleShot(450,&loop,&QEventLoop::quit);loop.exec();}
int main(int argc,char**argv){
    qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");
    QGuiApplication app(argc,argv);
    try {
        check(argc==3,"use: native-surface-view wrapper.qml mesh.json");
        QFile data(QString::fromLocal8Bit(argv[2]));check(data.open(QIODevice::ReadOnly),"mesh missing");
        auto mesh=QJsonDocument::fromJson(data.readAll()).object().toVariantMap();
        const auto vertices=mesh.value("vertices").toList();check(vertices.size()>3,"recorded native vertices missing");
        double south=90,north=-90,west=180,east=-180;
        for(const auto& v:vertices){const auto p=v.toList();south=std::min(south,p[0].toDouble());north=std::max(north,p[0].toDouble());west=std::min(west,p[1].toDouble());east=std::max(east,p[1].toDouble());}
        QQuickView view;view.setResizeMode(QQuickView::SizeRootObjectToView);view.resize(960,540);
        view.setSource(QUrl::fromLocalFile(QFileInfo(QString::fromLocal8Bit(argv[1])).absoluteFilePath()));
        check(view.status()==QQuickView::Ready,"native Canvas wrapper failed to load");
        auto* root=view.rootObject();auto* overlay=root->findChild<QQuickItem*>("surfaceOverlay");check(overlay,"production overlay missing");
        root->setProperty("latitude",(south+north)/2);root->setProperty("longitude",(west+east)/2);
        root->setProperty("scale",400/std::max(north-south,east-west));root->setProperty("mesh",mesh);
        view.show();events();check(overlay->property("renderedTriangles").toInt()>0,"no native triangles painted");
        const QImage first=view.grabWindow();check(!first.isNull(),"native Canvas screenshot empty");
        check(first.save("kogger-native-surface.png"),"native screenshot save failed");
        root->setProperty("longitude",(west+east)/2+(east-west)/4);events();
        check(view.grabWindow()!=first,"map pan did not invalidate projection");
        root->setProperty("scale",root->property("scale").toDouble()*1.5);events();
        check(overlay->property("renderedTriangles").toInt()>0,"zoom lost native surface");
        view.resize(540,960);events();check(overlay->property("renderedTriangles").toInt()>0,"resize lost surface");
        check(view.grabWindow().save("kogger-native-surface-portrait.png"),"portrait save failed");
        mesh["indices"]=QVariantList{-1,1,2,999999,1,2,0.5,1,2};root->setProperty("mesh",mesh);events();
        check(overlay->property("renderedTriangles").toInt()==0,"invalid indices rendered");
        root->setProperty("mesh",QVariantMap());events();check(!overlay->isVisible(),"empty mesh remains visible");
        std::cout<<"PASS production native Canvas: recorded topology, pan/zoom/resize, malformed indices and empty mesh. Projection test double; not Android/QtLocation acceptance.\n";
    } catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
