#pragma once
#include <QObject>
#include <QFile>
#include <QTimer>
#include <QElapsedTimer>
#include <QUrl>
#include <memory>
namespace Parsers { class FrameParser; }
class NavoKoggerReplay : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool active READ active NOTIFY stateChanged)
 Q_PROPERTY(bool paused READ paused NOTIFY stateChanged)
 Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY stateChanged)
 Q_PROPERTY(qint64 position READ position NOTIFY progressChanged)
 Q_PROPERTY(qint64 size READ size NOTIFY progressChanged)
 Q_PROPERTY(QString error READ error NOTIFY stateChanged)
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
 Q_INVOKABLE bool open(const QUrl& url);
 Q_INVOKABLE void stop();
 Q_INVOKABLE void setPaused(bool paused);
 Q_INVOKABLE void setSpeed(double speed);
signals:
 void positionReady(double latitude,double longitude,double heading,double pitch,double roll);
 void bytesReady(const QByteArray& bytes);
 void stateChanged();
 void progressChanged();
private:
 QFile _file;
 QTimer _timer;
 QElapsedTimer _pacing;
 std::unique_ptr<Parsers::FrameParser> _parser;
 bool _blocked=false, _gpsFix=false;
 double _lat=qQNaN(),_lon=qQNaN(),_heading=qQNaN(),_pitch=qQNaN(),_roll=qQNaN();
 bool _active=false, _paused=false;
 double _speed=1.0;
 QString _error;
 void readPosition();
private slots:
 void tick();
};
