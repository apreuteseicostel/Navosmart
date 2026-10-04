#include "../../custom/src/NavoPersistence.h"
#include <QCoreApplication>
#include <QDataStream>
#include <QSettings>
#include <QTemporaryDir>
#include <QSignalSpy>
#include <QProcess>
#include <QJsonArray>
#include <QJsonDocument>
#include <QtTest>

static bool failWrites=false;
static bool readSettings(QIODevice& device,QSettings::SettingsMap& map){QDataStream stream(&device);stream>>map;return stream.status()==QDataStream::Ok;}
static bool writeSettings(QIODevice& device,const QSettings::SettingsMap& map){if(failWrites)return false;QDataStream stream(&device);stream<<map;return stream.status()==QDataStream::Ok;}
class PersistenceTests:public QObject {
 Q_OBJECT
private slots:
 void catalogMigrationDeletionAndRollback() {
  QTemporaryDir directory;QVERIFY(directory.isValid());
  const auto format=QSettings::registerFormat("navotest",readSettings,writeSettings);
  QSettings::setDefaultFormat(format);QSettings::setPath(format,QSettings::UserScope,directory.path());
  {QSettings legacy;legacy.setValue("navo/lakes",QByteArray("[{\"id\":\"legacy\",\"name\":\"Old\"}]"));legacy.sync();}
  NavoPersistence store;QCOMPARE(store.lakes().size(),1);
  QVERIFY(!store.saveLake({{"id","other"},{"name","Other"}}).isEmpty());
  const QVariantList samples{QVariantMap{{"depth",2}},QVariantMap{{"depth",3}},QVariantMap{{"depth",4}}};
  QVERIFY(!store.saveBathymetrySession({{"id","session"},{"lakeId","legacy"}},samples).isEmpty());
  const auto lakes=store.lakes(),sessions=store.bathymetrySessions();
  QSignalSpy lakeSignals(&store,&NavoPersistence::lakesChanged),sessionSignals(&store,&NavoPersistence::bathymetrySessionsChanged);
  failWrites=true;
  QVERIFY(!store.deleteLake("legacy"));QCOMPARE(store.lakes(),lakes);QCOMPARE(store.bathymetrySessions(),sessions);
  QCOMPARE(lakeSignals.count(),0);QCOMPARE(sessionSignals.count(),0);
  QVERIFY(store.saveLake({{"id","failed"},{"name","Failed"}}).isEmpty());QCOMPARE(store.lakes(),lakes);
  QVERIFY(!store.assignSessionToLake("session","other"));QCOMPARE(store.bathymetrySessions(),sessions);
  failWrites=false;{QSettings settings;settings.sync();}
  {NavoPersistence reopened;QCOMPARE(reopened.lakes(),lakes);QCOMPARE(reopened.bathymetrySessions(),sessions);}
  QProcess afterFailedDelete;afterFailedDelete.start(QCoreApplication::applicationFilePath(),{"--inspect",directory.path()});
  QVERIFY(afterFailedDelete.waitForFinished(5000));QCOMPARE(afterFailedDelete.exitCode(),0);
  const auto failedDisk=QJsonDocument::fromJson(afterFailedDelete.readAllStandardOutput()).array();
  QCOMPARE(failedDisk[0].toArray().toVariantList(),lakes);QCOMPARE(failedDisk[1].toArray().toVariantList(),sessions);
  QVERIFY(store.deleteLake("legacy"));QCOMPARE(store.lakes().size(),1);QCOMPARE(store.bathymetrySessions().size(),0);
  {NavoPersistence reopened;QCOMPARE(reopened.lakes().size(),1);QCOMPARE(reopened.lakes()[0].toMap().value("id").toString(),QString("other"));QCOMPARE(reopened.bathymetrySessions().size(),0);}
  QProcess afterSuccessfulDelete;afterSuccessfulDelete.start(QCoreApplication::applicationFilePath(),{"--inspect",directory.path()});
  QVERIFY(afterSuccessfulDelete.waitForFinished(5000));QCOMPARE(afterSuccessfulDelete.exitCode(),0);
  const auto deletedDisk=QJsonDocument::fromJson(afterSuccessfulDelete.readAllStandardOutput()).array();
  QCOMPARE(deletedDisk[0].toArray().toVariantList(),store.lakes());QCOMPARE(deletedDisk[1].toArray().size(),0);
  QVERIFY(!store.deleteLake("legacy"));
 }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("NavoAudit");app.setApplicationName("Persistence");if(argc==3 && QString::fromLocal8Bit(argv[1])=="--inspect"){
 const auto format=QSettings::registerFormat("navotest",readSettings,writeSettings);
 QSettings::setDefaultFormat(format);QSettings::setPath(format,QSettings::UserScope,QString::fromLocal8Bit(argv[2]));
 NavoPersistence store;
 const QByteArray json=QJsonDocument(QJsonArray{QJsonArray::fromVariantList(store.lakes()),QJsonArray::fromVariantList(store.bathymetrySessions())}).toJson(QJsonDocument::Compact);
 fwrite(json.constData(),1,size_t(json.size()),stdout);return 0;
}PersistenceTests test;return QTest::qExec(&test,argc,argv);}
#include "persistence.moc"
