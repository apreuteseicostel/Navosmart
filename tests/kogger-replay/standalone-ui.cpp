// Launch *production* Experiment B QML with mock backends and verify
// independent file controls plus absence of any QGC or vehicle dependency.
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQuickView>
#include <QQuickItem>
#include <QFileInfo>
#include <QTimer>
#include <QEventLoop>
#include <QTest>
#include <iostream>
#include <stdexcept>
static void check(bool ok,const char* msg){if(!ok)throw std::runtime_error(msg);}
static void events(int milliseconds=120){
 QEventLoop loop;QTimer::singleShot(milliseconds,&loop,&QEventLoop::quit);loop.exec();
}
int main(int argc,char**argv){
 qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");
 QGuiApplication app(argc,argv);
 try{
  check(argc==3,"usage: navo-kogger-standalone-ui source.qml mock-import-root");
  QQuickView view;
  view.engine()->addImportPath(QString::fromLocal8Bit(argv[2]));
  view.setResizeMode(QQuickView::SizeRootObjectToView);
  view.resize(960,540);
  view.setSource(QUrl::fromLocalFile(QFileInfo(QString::fromLocal8Bit(argv[1])).absoluteFilePath()));
  check(view.status()==QQuickView::Ready,"production Experiment B QML failed to load");
  auto* root=view.rootObject();
  check(root && root->objectName()==QStringLiteral("koggerStandalonePage"),
        "wrong Kogger standalone root");
  check(!root->property("fileMode").toBool(),"initial B workspace must be offline");
  auto* open=root->findChild<QQuickItem*>("koggerBOpenFile");
  auto* close=root->findChild<QQuickItem*>("koggerBClose");
  auto* slider=root->findChild<QQuickItem*>("koggerBFullFileTimeline");
  auto* echo=root->findChild<QQuickItem*>("koggerBOriginalDataEchogram");
  check(open&&close&&slider&&echo,"Kogger standalone core controls missing");
  view.show();events(350);
  check(open->isVisible() && close->isVisible() && echo->width()>50 && echo->height()>50,
        "Kogger menu/echo controls invisible or clipped");
  QMetaObject::invokeMethod(root,"openFile",Q_ARG(QVariant,QVariant(QUrl("file:///tmp/test.klf"))));
  events(300);
  check(root->property("fileMode").toBool(),"standalone KLF mode did not activate");
  check(root->property("total").toInt()==6925,"B simulated KLF index missing");
  check(slider->isEnabled(),"full file slider disabled after index");
  root->setProperty("horizontalZoom",8);
  events();
  check(root->property("windowColumns").toInt()==866,"8x zoom must cover index proportionally");
  root->setProperty("selectedColumn",6000);
  events();
  check(root->property("windowStart").toInt()>0,"timeline cannot navigate end of KLF");
  check(view.grabWindow().save("kogger-b-standalone.png"),
        "cannot capture Kogger B native-QML screen");
  QMetaObject::invokeMethod(root,"closeSession");
  events();
  check(!root->property("fileMode").toBool(),"B KLF session not closed");
  std::cout<<"PASS standalone B QML loads, timeline/zoom and close work"<<std::endl;
  return 0;
 }catch(const std::exception& e){std::cerr<<e.what()<<std::endl;return 2;}
}
