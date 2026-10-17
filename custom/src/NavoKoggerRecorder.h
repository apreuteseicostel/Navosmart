#pragma once
#include <QObject>
#include <QSaveFile>
#include <QElapsedTimer>
#include <QVariantList>
#include <memory>

class NavoKoggerRecorder : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY changed)
    Q_PROPERTY(qint64 bytes READ bytes NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString savedName READ savedName NOTIFY changed)
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY changed)
public:
    explicit NavoKoggerRecorder(QObject* parent = nullptr);
    ~NavoKoggerRecorder() override;
    bool recording() const { return bool(_file); }
    qint64 bytes() const { return _bytes; }
    QString error() const { return _error; }
    QString savedName() const { return _savedName; }
    QVariantList sessions() const { return _sessions; }
    Q_INVOKABLE bool start(const QString& name);
    Q_INVOKABLE bool stop();
    Q_INVOKABLE void append(const QByteArray& bytes, double lat, double lon, double heading, double pitch, double roll);
    Q_INVOKABLE void refresh();
signals:
    void changed();
private:
    QString directory() const;
    void fail(const QString& error);
    std::unique_ptr<QSaveFile> _file;
    QElapsedTimer _clock;
    qint64 _bytes = 0, _lastNotification = 0;
    QString _error, _name, _savedName;
    QVariantList _sessions;
};
