#pragma once
#include <QQuickPaintedItem>
#include <QPointer>
#include <QHash>
#include <QMutex>
#include <QQueue>
#include <QTimer>
#include <QByteArray>
#include <QImage>
#include <QVariantMap>
#include <QVector>
#include <QtGlobal>
#include <QUuid>
#include "NavoKoggerReplay.h"

class NavoKoggerEpochPlotItem : public QQuickPaintedItem {
    Q_OBJECT
    // Native Kogger Epoch::chartTo sampling and original 256-shade palette.
    // This is a focused plot adapter, NOT the upstream KoggerApp process/Core.
    Q_PROPERTY(QObject* fileReplay READ fileReplay WRITE setFileReplay NOTIFY fileReplayChanged)
    Q_PROPERTY(int indexedColumns READ indexedColumns NOTIFY dataChanged)
    Q_PROPERTY(bool fileReady READ fileReady NOTIFY dataChanged)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY viewChanged)
    Q_PROPERTY(int horizontalZoom READ horizontalZoom WRITE setHorizontalZoom NOTIFY viewChanged)
    Q_PROPERTY(double depthFrom READ depthFrom WRITE setDepthFrom NOTIFY viewChanged)
    Q_PROPERTY(double depthRange READ depthRange WRITE setDepthRange NOTIFY viewChanged)
    Q_PROPERTY(int palette READ palette WRITE setPalette NOTIFY viewChanged)
    Q_PROPERTY(double levelLow READ levelLow WRITE setLevelLow NOTIFY viewChanged)
    Q_PROPERTY(double levelHigh READ levelHigh WRITE setLevelHigh NOTIFY viewChanged)
    Q_PROPERTY(bool compensate READ compensate WRITE setCompensate NOTIFY viewChanged)
public:
    explicit NavoKoggerEpochPlotItem(QQuickItem* parent=nullptr);
    QObject* fileReplay() const {return _file;}
    void setFileReplay(QObject* source);
    int indexedColumns() const;
    bool fileReady() const;
    double position() const {return _position;}
    void setPosition(double val);
    int horizontalZoom() const {return _zoom;}
    void setHorizontalZoom(int z);
    double depthFrom() const {return _from;}
    void setDepthFrom(double v);
    double depthRange() const {return _range;}
    void setDepthRange(double v);
    int palette() const {return _palette;}
    void setPalette(int v);
    double levelLow() const {return _low;}
    void setLevelLow(double v);
    double levelHigh() const {return _high;}
    void setLevelHigh(double v);
    bool compensate() const {return _compensate;}
    void setCompensate(bool v);
    Q_INVOKABLE QVariantMap inspectAt(double x,double y) const;
    void paint(QPainter* painter) override;
signals:
    void fileReplayChanged();
    void dataChanged();
    void viewChanged();
protected:
    void geometryChange(const QRectF& next,const QRectF& previous) override;
private:
    // Screen-height indexed amplitudes, not raw KLF payloads. Bounded on-device raster cache.
    struct FileColumn {QByteArray raster;};
    QPointer<NavoKoggerReplay> _file;
    mutable QMutex _cacheMutex;
    QHash<int,FileColumn> _cache;
    QQueue<int> _order;
    qint64 _cachedBytes=0;
    QTimer _loadTimer,_refreshTimer;
    QImage _lastCompleteFrame; // Previous valid viewport during an indexed KLF pan
    QUuid _sourceUuid;
    double _position=0.5,_from=0,_range=50,_low=10,_high=100;
    int _zoom=1,_palette=0;
    bool _compensate=false;
    static constexpr int MaxBytes=20*1024*1024;
    static constexpr int MaxEntries=4096;
    int sourceColumn(int screenX,int columns,int screenWidth) const;
    void clearFileCache();
    void loadVisibleBatch();
    void queueVisible();
    QVector<QRgb> colors() const;
};
