#include "NavoFpvItem.h"
#include <QGuiApplication>
#include <QQuickWindow>
#include <QJsonDocument>
#include <QJsonObject>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QtCore/qnativeinterface.h>
#endif
namespace { constexpr const char* bridge="org/navosmart/video/SkydroidVideoBridge"; }
NavoFpvItem::NavoFpvItem(QQuickItem* parent):QQuickItem(parent) {
    _poll.setInterval(150);
    connect(&_poll,&QTimer::timeout,this,&NavoFpvItem::poll);
    connect(this,&NavoFpvItem::configurationChanged,this,[this]{close();poll();});
    connect(this,&QQuickItem::visibleChanged,this,&NavoFpvItem::poll);
    connect(qGuiApp,&QGuiApplication::applicationStateChanged,this,[this]{poll();});
}
NavoFpvItem::~NavoFpvItem(){close();}
void NavoFpvItem::setActive(bool active){
    if(_active==active)return;
    _active=active;
    if(active)_poll.start();else {_poll.stop();close();}
    poll();emit changed();
}
void NavoFpvItem::close(){
#ifdef Q_OS_ANDROID
    if(_session)QJniObject::callStaticMethod<void>(bridge,"stop","(J)V",jlong(_session));
#endif
    _session=0;_connected=false;_live=false;_taps=0;
    _lastRect={};_lastClip={};_status="STOPPED";
}
void NavoFpvItem::poll(){
    const auto oldStatus=_status;const bool wasLive=_live,wasConnected=_connected;
    const QRectF full=mapRectToScene(boundingRect());
    QRectF clipped=full;
    for(auto* p=parentItem();p;p=p->parentItem())if(p->clip())clipped=clipped.intersected(p->mapRectToScene(p->boundingRect()));
    if(window())clipped=clipped.intersected(QRectF(0,0,window()->width(),window()->height()));
    bool popup=false;
    if(window())for(auto* p=window()->activeFocusItem();p;p=p->parentItem())
        if(QString::fromLatin1(p->metaObject()->className()).contains("PopupItem")){popup=true;break;}
    if(popup || !_active || !isVisible() || !window() || !window()->isVisible() || clipped.isEmpty() ||
       QGuiApplication::applicationState()!=Qt::ApplicationActive){
        close();
    }else{
#ifdef Q_OS_ANDROID
        if(!_session){
            if(!QJniObject::callStaticMethod<jboolean>(bridge,"supported","()Z"))_status="FPV indisponibil pe acest ABI";
            else {
                auto context=QNativeInterface::QAndroidApplication::context();
                auto url=QJniObject::fromString(_url);auto transport=QJniObject::fromString(_transport);
                _session=QJniObject::callStaticMethod<jlong>(bridge,"start","(Landroid/content/Context;Ljava/lang/String;ZLjava/lang/String;Z)J",
                    context.object(),url.object<jstring>(),jboolean(_hardware),transport.object<jstring>(),jboolean(_autoReconnect));
                _status=_session ? "FPV • conectare" : "FPV • pornire indisponibilă";
            }
        }
        if(_session){
            const qreal scale=window()->devicePixelRatio();
            const QPointF origin=mapToGlobal(QPointF(0,0));
            const QRect rect(qRound(origin.x()*scale),qRound(origin.y()*scale),qRound(width()*scale),qRound(height()*scale));
            const QRect clip(qRound((clipped.x()-full.x())*scale),qRound((clipped.y()-full.y())*scale),qRound(clipped.width()*scale),qRound(clipped.height()*scale));
            if(rect!=_lastRect || clip!=_lastClip){
                _lastRect=rect;_lastClip=clip;
                QJniObject::callStaticMethod<void>(bridge,"rect","(JIIIIIIII)V",jlong(_session),jint(rect.x()),jint(rect.y()),jint(rect.width()),jint(rect.height()),
                    jint(clip.x()),jint(clip.y()),jint(clip.x()+clip.width()),jint(clip.y()+clip.height()));
            }
            auto json=QJniObject::callStaticObjectMethod(bridge,"snapshot","(J)Ljava/lang/String;",jlong(_session));
            const auto s=QJsonDocument::fromJson(json.toString().toUtf8()).object();
            _connected=s.value("connected").toBool();
            const auto age=s.value("age").toInteger(-1);
            _live=age>=0 && age<3000;
            const QString error=s.value("error").toString();
            _status=!error.isEmpty()?error:_live?QString("LIVE • FPV • %1 cerut • %2×%3 • %4 cadre").arg(_hardware?"HW":"SW").arg(s.value("width").toInt()).arg(s.value("height").toInt()).arg(s.value("frames").toInteger())
                :_connected?"FPV conectat • cadre decodate neconfirmate":"FPV • conectare / reconectare";
            const int taps=s.value("taps").toInt();if(taps!=_taps){_taps=taps;emit tapped();}
        }
#else
        _status="FPV Player este disponibil în Android ARM";
#endif
    }
    if(oldStatus!=_status || wasLive!=_live || wasConnected!=_connected)emit changed();
}
