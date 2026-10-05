#include "../../custom/src/NavoAndroidAcceptance.h"
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <memory>
#include <iostream>
int main(int argc,char** argv) {
    QGuiApplication app(argc,argv);NavoAndroidAcceptance backend;
    QQuickWindow window;QQuickItem dashboard(window.contentItem());dashboard.setSize({640,480});
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
    std::cout<<"PASS acceptance owner isolation and real QtQuick Loader/visual traversal\n";
}
