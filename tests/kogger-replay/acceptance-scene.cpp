#include "../../custom/src/NavoAndroidAcceptance.h"
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <memory>
#include <iostream>
int main(int argc,char** argv) {
    qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");
    QGuiApplication app(argc,argv);NavoAndroidAcceptance backend;
    QQuickWindow window;window.resize(640,480);QQuickItem dashboard(window.contentItem());dashboard.setSize({640,480});
    if(backend.claim(&dashboard))return 1;
    window.show();app.processEvents();if(!backend.claim(&dashboard))return 2;
    QQuickItem duplicate(window.contentItem());duplicate.setSize({640,480});
    if(backend.claim(&duplicate))return 3;
    QQmlEngine engine;QQmlComponent component(&engine);
    component.setData(R"(import QtQuick
        Item { Loader { active:true; sourceComponent:Component {
            Item { objectName:"navoSonarPro"; property var history:[[],[],[]] }
        } } })",QUrl());
    std::unique_ptr<QObject> scene(component.create());
    if(!scene){qWarning()<<component.errors();return 4;}
    // Visual parentage can cross QObject ownership boundaries.
    qobject_cast<QQuickItem*>(scene.get())->setParentItem(&dashboard);
    if(backend.inspect(&dashboard).value("sonarHistoryColumns").toInt()!=3)return 5;
    if(!backend.claim(&dashboard))return 6;
    QQuickItem view(&dashboard);view.setObjectName("navoBathymetry3D");view.setSize({640,480});
    if(!backend.inspect(&dashboard).value("mesh3dVisible").toBool())return 7;
    view.setVisible(false);
    if(backend.inspect(&dashboard).value("mesh3dVisible").toBool())return 8;
    view.setVisible(true);view.setWidth(0);
    if(backend.inspect(&dashboard).value("mesh3dVisible").toBool())return 9;
    QQuickItem hidden(window.contentItem());hidden.setObjectName("savedSpotPin");hidden.setVisible(false);
    QQuickItem marker(window.contentItem());marker.setObjectName("savedSpotPin");marker.setPosition({100,80});marker.setSize({90,36});
    if(backend.control(&dashboard,"savedSpotPin")!=&marker)return 10;
    const auto position=backend.savedSpotPinPosition(&dashboard);
    if(position.value("x").toInt()!=qRound(145*window.devicePixelRatio()) || position.value("y").toInt()!=qRound(98*window.devicePixelRatio()))return 11;
    marker.setPosition({1000,80});
    if(!backend.savedSpotPinPosition(&dashboard).isEmpty())return 12;
    marker.setVisible(false);
    if(!backend.savedSpotPinPosition(&dashboard).isEmpty())return 13;
    std::cout<<"PASS acceptance owner isolation and real QtQuick Loader/visual traversal, visible control selection and physical marker coordinates\n";
}
