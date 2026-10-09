#include "NavoKoggerRecorder.h"
#include "NavoSonarArchive.h"
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QUuid>
#include <QUrl>
#include <QStorageInfo>

NavoKoggerRecorder::NavoKoggerRecorder(QObject* parent): QObject(parent) { refresh(); }
NavoKoggerRecorder::~NavoKoggerRecorder() { if (_file) stop(); }
QString NavoKoggerRecorder::directory() const {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/sonar-recordings";
}
void NavoKoggerRecorder::fail(const QString& error) {
    if (_file) _file->cancelWriting();
    _file.reset(); _error = error; emit changed();
}
bool NavoKoggerRecorder::start(const QString& name) {
    if (_file) return false;
    _error.clear(); _savedName.clear(); _bytes = 0; _lastNotification = 0;
    _name = name.trimmed().left(120);
    if (_name.isEmpty()) _name = QStringLiteral("Sesiune sonar");
    if (!QDir().mkpath(directory())) { fail(QStringLiteral("Nu pot crea folderul de înregistrări.")); return false; }
    // Keep a 64 MiB reserve at start. Write errors cancel the current file.
    const QStorageInfo storage(directory());
    if (storage.isValid() && storage.bytesAvailable() < 64LL*1024*1024) {
        fail(QStringLiteral("Spațiu insuficient: sunt necesari cel puțin 64 MiB liberi.")); return false;
    }
    const auto now = QDateTime::currentDateTimeUtc();
    const auto path = directory() + '/' + now.toString("yyyyMMdd-HHmmss-zzz") + '-' + QUuid::createUuid().toString(QUuid::Id128) + ".navosonar";
    _file = std::make_unique<QSaveFile>(path);
    _file->setDirectWriteFallback(false);
    if (!_file->open(QIODevice::WriteOnly) || !NavoSonarArchive::writeHeader(*_file,
        {{"version", 1}, {"name", _name}, {"createdUtc", now.toString(Qt::ISODateWithMs)}, {"poseSource", "H743-reception"}})) {
        fail(QStringLiteral("Nu pot deschide înregistrarea: ") + _file->errorString()); return false;
    }
    _clock.start(); emit changed(); return true;
}
void NavoKoggerRecorder::append(const QByteArray& bytes, double lat, double lon, double heading, double pitch, double roll) {
    if (!_file || bytes.isEmpty()) return;
    if (_clock.elapsed() > 7LL*24*3600*1000) { stop(); return; }
    NavoSonarArchive::Record record;
    record.milliseconds = _clock.elapsed();
    const bool fix = std::isfinite(lat) && std::isfinite(lon) && std::abs(lat) <= 90 && std::abs(lon) <= 180;
    record.lat = fix ? lat : qQNaN(); record.lon = fix ? lon : qQNaN();
    record.heading = std::isfinite(heading) ? heading : qQNaN();
    record.pitch = std::isfinite(pitch) ? pitch : qQNaN(); record.roll = std::isfinite(roll) ? roll : qQNaN();
    for (qsizetype offset = 0; offset < bytes.size(); offset += NavoSonarArchive::maxChunk) {
        record.bytes = bytes.mid(offset, NavoSonarArchive::maxChunk);
        if (_file->pos() + 84 + record.bytes.size() + 4 > NavoSonarArchive::maxFile) {
            stop(); _error = QStringLiteral("Limita de 512 MiB a fost atinsă. Pornește o sesiune nouă."); emit changed(); return;
        }
        if (!NavoSonarArchive::writeRecord(*_file, record)) {
            fail(QStringLiteral("Înregistrarea nu a fost salvată: ") + _file->errorString()); return;
        }
        _bytes += record.bytes.size();
    }
    if (record.milliseconds - _lastNotification >= 500 || _lastNotification == 0) {
        _lastNotification = record.milliseconds; emit changed();
    }
}
bool NavoKoggerRecorder::stop() {
    if (!_file) return false;
    if (_bytes == 0) { fail(QStringLiteral("Sesiunea nu conține date sonar.")); return false; }
    QDataStream stream(_file.get()); NavoSonarArchive::configure(stream); stream << quint32(0);
    if (stream.status() != QDataStream::Ok || !_file->commit()) {
        fail(QStringLiteral("Nu am putut salva sesiunea: ") + _file->errorString()); return false;
    }
    _file.reset(); _savedName = _name; refresh(); return true;
}
void NavoKoggerRecorder::refresh() {
    _sessions.clear();
    const auto entries = QDir(directory()).entryInfoList({"*.navosonar"}, QDir::Files, QDir::Name | QDir::Reversed);
    for (const auto& entry : entries) {
        QFile file(entry.filePath()); QJsonObject metadata;
        if (entry.size() > NavoSonarArchive::maxFile || !file.open(QIODevice::ReadOnly) || !NavoSonarArchive::readHeader(file, metadata)) continue;
        // Finalized files have the explicit end marker; replay checks every record.
        if (file.size() < file.pos() + 4 || !file.seek(file.size()-4) || file.read(4) != QByteArray(4, '\0')) continue;
        _sessions.append(QVariantMap{{"name", metadata.value("name").toString()}, {"createdUtc", metadata.value("createdUtc").toString()},
            {"size", entry.size()}, {"url", QUrl::fromLocalFile(entry.filePath())}});
    }
    emit changed();
}
