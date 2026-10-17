#pragma once
#include <QObject>
#include <QFile>
#include <QTimer>
#include <QElapsedTimer>
#include <QUrl>
#include <QVariantList>
#include <memory>
#include "NavoSonarArchive.h"
namespace Parsers { class FrameParser; }
class NavoKoggerReplay : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool active READ active NOTIFY stateChanged)
 Q_PROPERTY(bool paused READ paused NOTIFY stateChanged)
 Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY stateChanged)
 Q_PROPERTY(qint64 position READ position NOTIFY progressChanged)
 Q_PROPERTY(qint64 size READ size NOTIFY progressChanged)
 Q_PROPERTY(QString error READ error NOTIFY stateChanged)
 Q_PROPERTY(QVariantMap annotationAnchor READ annotationAnchor NOTIFY annotationAnchorChanged)
 Q_PROPERTY(QVariantList annotations READ annotations NOTIFY annotationsChanged)
 Q_PROPERTY(QString annotationError READ annotationError NOTIFY annotationsChanged)
public:
 explicit NavoKoggerReplay(QObject* parent=nullptr);
 ~NavoKoggerReplay() override;
 Q_INVOKABLE void setBlocked(bool blocked) { if(_blocked!=blocked){_blocked=blocked;_pacing.start();} }
 bool active() const { return _active; }
 bool paused() const { return _paused; }
 double speed() const { return _speed; }
 qint64 position() const { return _file.pos(); }
 qint64 size() const { return _file.size(); }
 QString error() const { return _error; }
 QVariantMap annotationAnchor() const;
 QVariantList annotations() const { return _annotations; }
 QString annotationError() const { return _annotationError; }
 Q_INVOKABLE bool saveAnnotation(const QVariantMap& anchor, const QString& text, double depth, double temperature);
 Q_INVOKABLE bool editAnnotation(const QString& id, const QString& text);
 Q_INVOKABLE bool removeAnnotation(const QString& id);
 Q_INVOKABLE bool open(const QUrl& url);
 Q_INVOKABLE void stop();
 Q_INVOKABLE void setPaused(bool paused);
 Q_INVOKABLE void setSpeed(double speed);
signals:
 void positionReady(double latitude,double longitude,double heading,double pitch,double roll);
 void bytesReady(const QByteArray& bytes);
 void stateChanged();
 void progressChanged();
 void annotationsChanged();
 void annotationAnchorChanged();
private:
 QString _annotationKey, _annotationError;
 QVariantList _annotations;
 qint64 _deliveredFrame=0, _deliveredMilliseconds=-1;
 bool _annotationsWritable=true;
 QString annotationPath() const;
 void loadAnnotations(const QUrl& url);
 bool storeAnnotations(const QVariantList& next);
 QFile _file;
 QTimer _timer;
 QElapsedTimer _pacing;
 std::unique_ptr<Parsers::FrameParser> _parser;
 bool _blocked=false, _gpsFix=false;
 double _lat=qQNaN(),_lon=qQNaN(),_heading=qQNaN(),_pitch=qQNaN(),_roll=qQNaN();
 bool _active=false, _paused=false;
 double _speed=1.0;
 QString _error;
 bool _archive=false, _pending=false;
 double _archiveTime=0;
 qint64 _previousTime=0;
 NavoSonarArchive::Record _record;
 void archiveTick(qint64 elapsed);
 void readPosition();
private slots:
 void tick();
};
