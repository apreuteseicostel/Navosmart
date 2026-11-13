#include "NavoBackup.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QSet>
#include <QSettings>
#include <QVariantMap>

namespace {
constexpr qint64 maxBytes = 64 * 1024 * 1024;
const QString pendingKey = QStringLiteral("navoBackup/pendingV1");
const QString format = QStringLiteral("navo-smart-backup");

QString documentPath(const QUrl& url)
{
    const auto local = url.toLocalFile();
    if (url.isLocalFile() && url.host().isEmpty() && QDir::isAbsolutePath(local))
        return local;
#ifdef Q_OS_ANDROID
    if (url.scheme() == QLatin1String("content") && !url.host().isEmpty())
        return url.toString();
#endif
    return {};
}

bool allowedPreference(const QString& key)
{
    static const QSet<QString> groups{
        "NavoAlerts", "NavoBaiting", "NavoConnectivity", "NavoEnergy", "NavoEnvironment",
        "NavoEthernet", "NavoG20", "NavoHopperCalibration", "NavoLanDiagnostics",
        "NavoLights", "NavoMapLayers", "NavoSession", "NavoStealth"
    };
    static const QSet<QString> excluded{
        "NavoHopperCalibration/requestSequence", "NavoHopperCalibration/confirmed",
        "NavoEnergy/confirmed", "NavoG20/hardwareActionsEnabled"
    };
    const auto slash = key.indexOf('/');
    return slash > 0 && slash < key.size() - 1 && slash == key.lastIndexOf('/')
        && groups.contains(key.left(slash)) && !excluded.contains(key);
}

bool primitivePreference(const QJsonValue& value)
{
    return value.isBool() || value.isDouble() || (value.isString() && value.toString().size() <= 4096);
}

bool objectList(const QJsonValue& value)
{
    if (!value.isArray())
        return false;
    for (const auto& item : value.toArray())
        if (!item.isObject())
            return false;
    return true;
}

QJsonObject parse(const QByteArray& bytes)
{
    if (bytes.isEmpty() || bytes.size() > maxBytes)
        return {};
    const auto snapshot = QJsonDocument::fromJson(bytes).object();
    if (snapshot.value("format").toString() != format || snapshot.value("version").toDouble() != 1
        || !snapshot.value("preferences").isObject() || !snapshot.value("data").isObject())
        return {};

    const auto preferences = snapshot.value("preferences").toObject();
    for (auto it = preferences.begin(); it != preferences.end(); ++it)
        if (!allowedPreference(it.key()) || !primitivePreference(it.value()))
            return {};

    const auto data = snapshot.value("data").toObject();
    const auto catalog = data.value("catalog").toObject();
    if (catalog.value("version").toDouble() != 1 || !objectList(catalog.value("lakes"))
        || !objectList(catalog.value("sessions")) || !objectList(catalog.value("trips"))
        || !data.value("waypointNames").isObject() || !objectList(data.value("sonarSamples"))
        || !objectList(data.value("pendingBaitJournal")))
        return {};
    for (const auto& lake : catalog.value("lakes").toArray()) {
        const auto record = lake.toObject();
        if (record.value("id").toString().isEmpty() ||
            (record.contains("state") && !record.value("state").isObject()))
            return {};
    }
    for (const auto& trip : catalog.value("trips").toArray()) {
        const auto record = trip.toObject();
        if (record.value("id").toString().isEmpty() || !objectList(record.value("entries")))
            return {};
    }
    return snapshot;
}

bool writeSettings(QSettings& settings, const QVariantMap& changes)
{
    // An invalid QVariant represents an absent key. Keep a rollback snapshot
    // for QSettings' shared pending cache, including the staged backup key.
    QVariantMap previous;
    const auto apply = [&settings](const QString& key, const QVariant& value) {
        if (value.isValid())
            settings.setValue(key, value);
        else
            settings.remove(key);
    };
    settings.setAtomicSyncRequired(true);
    for (auto it = changes.cbegin(); it != changes.cend(); ++it) {
        previous.insert(it.key(), settings.value(it.key()));
        apply(it.key(), it.value());
    }
    settings.sync();
    if (settings.status() == QSettings::NoError)
        return true;
    for (auto it = previous.cbegin(); it != previous.cend(); ++it)
        apply(it.key(), it.value());
    settings.sync();
    return false;
}

QByteArray encode(const QJsonValue& value)
{
    return (value.isArray() ? QJsonDocument(value.toArray()) : QJsonDocument(value.toObject()))
        .toJson(QJsonDocument::Compact);
}
}

bool NavoBackup::writeDocument(const QUrl& destination, const QByteArray& bytes)
{
    const auto path = documentPath(destination);
    if (path.isEmpty())
        return false;
    if (destination.isLocalFile()) {
        QSaveFile file(path);
        return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size() && file.commit();
    }

    // Android document providers may not support QSaveFile's sibling rename.
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    const bool written = file.write(bytes) == bytes.size() && file.flush();
    file.close();
    return written && file.error() == QFileDevice::NoError;
}

QString NavoBackup::exportTo(const QUrl& destination, const QJsonObject& data)
{
    QSettings settings;
    settings.sync();
    if (settings.status() != QSettings::NoError)
        return QStringLiteral("Setările salvate nu pot fi citite.");
    QJsonObject preferences;
    for (const auto& key : settings.allKeys()) {
        if (!allowedPreference(key))
            continue;
        const auto value = QJsonValue::fromVariant(settings.value(key));
        if (primitivePreference(value))
            preferences.insert(key, value);
    }
    const auto bytes = QJsonDocument(QJsonObject{
        {"format", format}, {"version", 1}, {"preferences", preferences}, {"data", data}
    }).toJson(QJsonDocument::Compact);
    if (bytes.size() > maxBytes)
        return QStringLiteral("Copia de rezervă depășește limita de 64 MiB.");
    if (parse(bytes).isEmpty() || !writeDocument(destination, bytes))
        return QStringLiteral("Copia de rezervă nu a fost salvată. Verifică datele, destinația și spațiul disponibil.");
    return {};
}

QString NavoBackup::stageImport(const QUrl& source)
{
    QFile file(documentPath(source));
    if (file.fileName().isEmpty() || !file.open(QIODevice::ReadOnly))
        return QStringLiteral("Fișierul nu poate fi citit.");
    const auto bytes = file.read(maxBytes + 1);
    if (file.error() != QFileDevice::NoError || parse(bytes).isEmpty())
        return QStringLiteral("Fișier NAVO invalid, incompatibil sau mai mare de 64 MiB.");
    QSettings settings;
    if (!writeSettings(settings, {{pendingKey, bytes}}))
        return QStringLiteral("Copia nu a putut fi pregătită pentru restaurare.");
    return {};
}

bool NavoBackup::pending()
{
    return QSettings().contains(pendingKey);
}

QString NavoBackup::applyPending()
{
    QSettings settings;
    if (!settings.contains(pendingKey))
        return {};
    const auto snapshot = parse(settings.value(pendingKey).toByteArray());
    if (snapshot.isEmpty())
        return QStringLiteral("Copia pregătită este invalidă. Alege din nou un fișier NAVO.");
    const auto data = snapshot.value("data").toObject();
    auto changes = snapshot.value("preferences").toObject().toVariantMap();
    changes.insert("navo/catalogV1", encode(data.value("catalog")));
    changes.insert("navo/waypointNames", encode(data.value("waypointNames")));
    changes.insert("navo/sonarSamples", encode(data.value("sonarSamples")));
    changes.insert("navo/pendingBaitJournalV1", encode(data.value("pendingBaitJournal")));
    changes.insert("NavoHopperCalibration/confirmed", false);
    changes.insert("NavoEnergy/confirmed", false);
    changes.insert("NavoG20/hardwareActionsEnabled", false);
    changes.insert(pendingKey, QVariant());
    return writeSettings(settings, changes)
        ? QStringLiteral("Copia NAVO a fost restaurată.")
        : QStringLiteral("Restaurarea nu a fost aplicată. Verifică spațiul disponibil și repornește aplicația.");
}
