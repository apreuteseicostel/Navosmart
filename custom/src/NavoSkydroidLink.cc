#include "NavoSkydroidLink.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QJniEnvironment>
#include <QCoreApplication>
#include <QtCore/qnativeinterface.h>
namespace {
constexpr const char *bridge = "org/navosmart/connectivity/SkydroidBridge";
QVariantMap snapshot(qint64 session) {
    const auto json = QJniObject::callStaticObjectMethod(bridge, "snapshot", "(J)Ljava/lang/String;", jlong(session));
    return QJsonDocument::fromJson(json.toString().toUtf8()).object().toVariantMap();
}
}
#endif

NavoSkydroidLink::NavoSkydroidLink(SharedLinkConfigurationPtr &config, QObject *parent)
    : LinkInterface(config, parent) {
    _poll.setInterval(20);
    connect(&_poll, &QTimer::timeout, this, &NavoSkydroidLink::poll);
}
NavoSkydroidLink::~NavoSkydroidLink() { disconnect(); }
QVariantMap NavoSkydroidLink::deviceInfo() {
#ifdef Q_OS_ANDROID
    if (QJniObject::isClassAvailable(bridge)) return snapshot(0);
    return {{"supported", false}, {"arm", false}, {"error", "Adaptorul Android RCSDK lipsește din APK"}};
#else
    return {{"supported", false}, {"arm", false}, {"error", "RCSDK G20 este disponibil numai pe Android ARM"}};
#endif
}
bool NavoSkydroidLink::_connect() {
#ifdef Q_OS_ANDROID
    if (_session) return true;
    if (!QJniObject::isClassAvailable(bridge)) return false;
    const auto context = QNativeInterface::QAndroidApplication::context();
    _session = QJniObject::callStaticMethod<jlong>(bridge, "start", "(Landroid/content/Context;Z)J",
        context.object(), jboolean(QSettings().value("NavoConnectivity/g20Selected", false).toBool()));
    if (!_session) return false;
    _started.start(); _poll.start(); return true;
#else
    return false;
#endif
}
void NavoSkydroidLink::disconnect() {
    if (_stopping || !_session) return;
    _stopping = true; _poll.stop();
#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(bridge, "stop", "(J)V", jlong(_session));
#endif
    _session = 0; _connected = false;
    emit disconnected();
}
void NavoSkydroidLink::poll() {
#ifdef Q_OS_ANDROID
    if (!_session || _stopping) return;
    _diagnostics = snapshot(_session);
    const bool ready = _diagnostics.value("rc").toBool() && _diagnostics.value("channel").toBool();
    if (!ready) {
        if (_connected || _started.elapsed() > 20000) {
            QString error = _diagnostics.value("error").toString();
            if (error.isEmpty()) error = "Canal indisponibil • închide FLY/Device Tool și verifică receptorul/firmware-ul G20";
            emit communicationError("Skydroid G20 / GR01", error);
            disconnect();
        }
        return;
    }
    if (!_connected) { _connected = true; emit connected(); }
    // Bounded work per tick; Java also caps its receive backlog and expires it.
    for (int i = 0; i < 16; ++i) {
        const auto data = QJniObject::callStaticObjectMethod(bridge, "read", "(J)[B", jlong(_session));
        if (!data.isValid()) break;
        QJniEnvironment env;
        auto array = data.object<jbyteArray>(); const auto size = env->GetArrayLength(array);
        if (size <= 0) break;
        QByteArray bytes(size, Qt::Uninitialized);
        env->GetByteArrayRegion(array, 0, size, reinterpret_cast<jbyte *>(bytes.data()));
        emit bytesReceived(this, bytes);
    }
#endif
}
void NavoSkydroidLink::_writeBytes(const QByteArray &bytes) {
#ifdef Q_OS_ANDROID
    if (!_connected || !_session || _stopping || bytes.isEmpty()) return;
    QJniEnvironment env;
    auto array = env->NewByteArray(bytes.size());
    if (!array) return;
    env->SetByteArrayRegion(array, 0, bytes.size(), reinterpret_cast<const jbyte *>(bytes.constData()));
    const bool sent = QJniObject::callStaticMethod<jboolean>(bridge, "write", "(J[B)Z", jlong(_session), array);
    env->DeleteLocalRef(array);
    if (sent) emit bytesSent(this, bytes);
#else
    Q_UNUSED(bytes)
#endif
}
