#pragma once
#include <QDataStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <cmath>
#include <QCryptographicHash>

// NAVO v1 stores received wire chunks and reception-time H743 pose, not KLF.
namespace NavoSonarArchive {
inline const QByteArray magic("NAVOSONAR1\n");
constexpr quint32 maxChunk = 65536;
constexpr qint64 maxFile = 512LL * 1024 * 1024;
struct Record {
    qint64 milliseconds = 0;
    double lat = qQNaN(), lon = qQNaN(), heading = qQNaN(), pitch = qQNaN(), roll = qQNaN();
    QByteArray bytes;
};
inline void configure(QDataStream& stream) {
    stream.setVersion(QDataStream::Qt_6_0);
    stream.setByteOrder(QDataStream::LittleEndian);
    stream.setFloatingPointPrecision(QDataStream::DoublePrecision);
}
inline bool writeHeader(QIODevice& file, const QJsonObject& metadata) {
    const auto json = QJsonDocument(metadata).toJson(QJsonDocument::Compact);
    if (file.write(magic) != magic.size()) return false;
    QDataStream stream(&file); configure(stream);
    stream << quint32(json.size());
    return stream.status() == QDataStream::Ok && file.write(json) == json.size();
}
inline bool readHeader(QIODevice& file, QJsonObject& metadata) {
    if (file.read(magic.size()) != magic) return false;
    QDataStream stream(&file); configure(stream);
    quint32 length = 0; stream >> length;
    if (stream.status() != QDataStream::Ok || length == 0 || length > 4096) return false;
    const auto json = file.read(length);
    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(json, &error);
    if (json.size() != length || error.error != QJsonParseError::NoError || !document.isObject()) return false;
    metadata = document.object();
    return metadata.value("version").toInt() == 1;
}
inline bool writeRecord(QIODevice& file, const Record& record) {
    QByteArray header;
    QDataStream stream(&header, QIODevice::WriteOnly); configure(stream);
    stream << quint32(record.bytes.size()) << record.milliseconds << record.lat << record.lon
           << record.heading << record.pitch << record.roll;
    const auto hash = QCryptographicHash::hash(header + record.bytes, QCryptographicHash::Sha256);
    return stream.status() == QDataStream::Ok && file.write(header) == header.size() &&
           file.write(record.bytes) == record.bytes.size() && file.write(hash) == hash.size();
}
// 1 = record, 0 = explicit end marker, -1 = corrupt or incomplete.
inline int readRecord(QIODevice& file, Record& record, qint64 previous) {
    QByteArray header = file.read(4);
    QDataStream prefix(header); configure(prefix);
    quint32 length = 0; prefix >> length;
    if (prefix.status() != QDataStream::Ok || length > maxChunk) return -1;
    if (length == 0) return file.atEnd() ? 0 : -1;
    header += file.read(48);
    if (header.size() != 52) return -1;
    QDataStream stream(header); configure(stream); stream >> length;
    stream >> record.milliseconds >> record.lat >> record.lon >> record.heading >> record.pitch >> record.roll;
    if (stream.status() != QDataStream::Ok || record.milliseconds < previous || record.milliseconds > 7LL*24*3600*1000) return -1;
    for (double value : {record.lat, record.lon, record.heading, record.pitch, record.roll})
        if (std::isinf(value)) return -1;
    if (std::isnan(record.lat) != std::isnan(record.lon) ||
        (!std::isnan(record.lat) && std::abs(record.lat) > 90) ||
        (!std::isnan(record.lon) && std::abs(record.lon) > 180)) return -1;
    record.bytes = file.read(length);
    const auto hash = file.read(32);
    return record.bytes.size() == length && hash.size() == 32 &&
           hash == QCryptographicHash::hash(header + record.bytes, QCryptographicHash::Sha256) ? 1 : -1;
}
}
