#pragma once

#include <QByteArray>
#include <QJsonObject>
#include <QString>
#include <QUrl>

namespace NavoBackup {
bool writeDocument(const QUrl& destination, const QByteArray& bytes);
QString exportTo(const QUrl& destination, const QJsonObject& data);
QString stageImport(const QUrl& source);
bool pending();
QString applyPending();
}
