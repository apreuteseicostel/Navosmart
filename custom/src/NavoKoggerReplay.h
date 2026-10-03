#pragma once
#include <QObject>
#include <QFile>
#include <QTimer>
#include <QUrl>
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
 void bytesReady(const QByteArray& bytes);
 void stateChanged();
 void progressChanged();
private:
 QFile _file;
 QTimer _timer;
 QByteArray _pending;
 bool _active=false, _paused=false;
 double _speed=1.0;
 QString _error;
 void tick();
};
