#pragma once
#include <QQuickItem>
#include <QTimer>
#include <QRect>

// Android surface follows this item's visible/clipped rectangle; controls stay in QML.
class NavoFpvItem : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(QString streamUrl MEMBER _url NOTIFY configurationChanged)
    Q_PROPERTY(QString transport MEMBER _transport NOTIFY configurationChanged)
    Q_PROPERTY(bool autoReconnect MEMBER _autoReconnect NOTIFY configurationChanged)
    Q_PROPERTY(bool hardware MEMBER _hardware NOTIFY configurationChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY changed)
    Q_PROPERTY(bool playing READ playing NOTIFY changed)
    Q_PROPERTY(bool live READ live NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
public:
    explicit NavoFpvItem(QQuickItem* parent=nullptr);
    ~NavoFpvItem() override;
    bool active() const { return _active; }
    bool playing() const { return _connected; }
    bool live() const { return _live; }
    QString status() const { return _status; }
    void setActive(bool active);
signals:
    void configurationChanged();
    void changed();
    void tapped();
private:
    void poll();
    void close();
    QTimer _poll;
    QString _url, _transport="tcp", _status="STOPPED";
    bool _autoReconnect=true, _hardware=true, _active=false, _connected=false, _live=false;
    qint64 _session=0;
    int _taps=0;
    QRect _lastRect, _lastClip;
};
