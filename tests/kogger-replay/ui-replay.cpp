// Load the production Sonar PRO QML and render real CHART samples. Map-only
// dependencies are mocked and disabled; the echogram, controls and scale are
// the actual component. This is not an Android/QGroundControl runtime test.
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQuickView>
#include <QQuickItem>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QFileInfo>
#include <QTimer>
#include <QEventLoop>
#include <QTest>
#include <QSignalSpy>
#include <iostream>
#include <stdexcept>
static void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
static void events(){QEventLoop loop;QTimer::singleShot(1200,&loop,&QEventLoop::quit);loop.exec();}
int main(int argc,char**argv){
 qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");
 QGuiApplication app(argc,argv);
 try{
  check(argc==4,"use: ui-replay source.qml mock-imports columns.json");
  QFile data(QString::fromLocal8Bit(argv[3]));check(data.open(QIODevice::ReadOnly),"fixture columns missing");
  const auto columns=QJsonDocument::fromJson(data.readAll()).array();check(columns.size()==240,"need 240 actual columns");
  QQuickView view;view.engine()->addImportPath(QString::fromLocal8Bit(argv[2]));
  view.setResizeMode(QQuickView::SizeRootObjectToView);view.resize(960,540);
  view.setSource(QUrl::fromLocalFile(QFileInfo(QString::fromLocal8Bit(argv[1])).absoluteFilePath()));
  check(view.status()==QQuickView::Ready,"production Sonar PRO QML failed to load");
  auto* root=view.rootObject();check(root,"Sonar PRO root missing");
  const auto verifyControls=[&]{
      for(const char* name:{"sonarProMenuButton","sonarProCloseButton"}){
          auto* item=root->findChild<QQuickItem*>(name);
          check(item && item->isVisible() && item->isEnabled(),"close/menu control missing or disabled");
          check(item->x()>=0 && item->y()>=0 && item->x()+item->width()<=view.width()+1 &&
                item->y()+item->height()<=view.height()+1,"close/menu control outside viewport");
      }
  };
  root->setProperty("connected",true);root->setProperty("history",columns.toVariantList());
  // Delayed depth must update its own completed column, not the newest one.
  auto associationColumns=columns.toVariantList();
  for(int i=0;i<associationColumns.size();++i){auto entry=associationColumns[i].toMap();entry["sequence"]=i+1;associationColumns[i]=entry;}
  root->setProperty("history",associationColumns);
  check(QMetaObject::invokeMethod(root,"updateHistoryBottom",Q_ARG(QVariant,QVariant(43)),Q_ARG(QVariant,QVariant(8.25))),"cannot deliver delayed bottom result");
  const auto updated=root->property("history").toList();
  check(updated[42].toMap().value("bottom").toDouble()==8.25 && updated[43].toMap().value("bottom")==associationColumns[43].toMap().value("bottom"),"delayed depth changed the wrong ecogram column");
  root->setProperty("history",columns.toVariantList());
  view.show();events();verifyControls();
  auto* menu=root->findChild<QQuickItem*>("sonarProMenuButton");
  const auto menuPoint=menu->mapToScene(QPointF(menu->width()/2,menu->height()/2)).toPoint();
  QTest::mouseClick(&view,Qt::LeftButton,Qt::NoModifier,menuPoint);events();
  check(root->property("menuOpen").toBool(),"menu button did not open menu");
  check(view.grabWindow().save("kogger-sonar-pro-menu.png"),"cannot save menu screenshot");
  QTest::mouseClick(&view,Qt::LeftButton,Qt::NoModifier,menuPoint);events();
  check(!root->property("menuOpen").toBool(),"menu button did not close menu");
  const QImage night=view.grabWindow();check(!night.isNull(),"empty night screenshot");
  check(night.save("kogger-sonar-pro-night.png"),"cannot save night screenshot");
  root->setProperty("dayPalette",true);events();const QImage day=view.grabWindow();
  check(!day.isNull() && day!=night,"DAY palette did not change the rendered ecogram");
  check(day.save("kogger-sonar-pro-day.png"),"cannot save day screenshot");
  view.resize(540,960);events();verifyControls();check(view.grabWindow().save("kogger-sonar-pro-portrait.png"),"cannot save portrait screenshot");
  QSignalSpy closeSignal(root,SIGNAL(closed()));
  auto* close=root->findChild<QQuickItem*>("sonarProCloseButton");
  QTest::mouseClick(&view,Qt::LeftButton,Qt::NoModifier,close->mapToScene(QPointF(close->width()/2,close->height()/2)).toPoint());events();
  check(closeSignal.count()==1,"close button did not emit closed signal");
  check(root->property("mapEnabled").toBool()==false,"map mock unexpectedly active");
  std::cout<<"PASS production Sonar PRO QML: 240 actual columns, DAY/NAVO palettes, landscape/portrait rendering, delayed bottom association and menu/close clicks\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
