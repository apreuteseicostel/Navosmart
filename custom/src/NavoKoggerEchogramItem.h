#pragma once
#include <QQuickPaintedItem>
#include <QPointer>
#include <QByteArray>
#include <QMutex>
#include <QTimer>
#include <QVector>
#include <QColor>
#include <QHash>
#include <QQueue>
#include <QSet>
#include "NavoKoggerDecoder.h"

// Native KoggerApp-style 8-bit echogram for NAVO / QGroundControl.
// Reuses Kogger palette and Epoch::chartTo sampling, but avoids importing
// KoggerApp's whole Plot2D (navigation, Core, contacts, map) dependency tree.
// Live/replay input is the existing NavoKoggerDecoder; no MAVLink access.
class NavoKoggerEchogramItem : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QObject* decoder READ decoder WRITE setDecoder NOTIFY decoderChanged)
    Q_PROPERTY(qreal depthFrom READ depthFrom WRITE setDepthFrom NOTIFY displayChanged)
    Q_PROPERTY(qreal depthRange READ depthRange WRITE setDepthRange NOTIFY displayChanged)
    Q_PROPERTY(int paletteMode READ paletteMode WRITE setPaletteMode NOTIFY displayChanged)
    Q_PROPERTY(qreal lowLevel READ lowLevel WRITE setLowLevel NOTIFY displayChanged)
    Q_PROPERTY(qreal highLevel READ highLevel WRITE setHighLevel NOTIFY displayChanged)
    Q_PROPERTY(qreal gain READ gain WRITE setGain NOTIFY displayChanged)
    Q_PROPERTY(qreal noiseFloor READ noiseFloor WRITE setNoiseFloor NOTIFY displayChanged)
    Q_PROPERTY(bool frozen READ frozen WRITE setFrozen NOTIFY frozenChanged)
    Q_PROPERTY(bool showBottomTrack READ showBottomTrack WRITE setShowBottomTrack NOTIFY displayChanged)
    // Experiment C — upstream Kogger Epoch::chartTo pixel rules.
    Q_PROPERTY(bool upstreamRaster READ upstreamRaster WRITE setUpstreamRaster NOTIFY displayChanged)
    Q_PROPERTY(bool upstreamCompensated READ upstreamCompensated WRITE setUpstreamCompensated NOTIFY displayChanged)
    Q_PROPERTY(int columnCount READ columnCount NOTIFY columnsChanged)
    // Full-file KLF viewer: independent of the decoder's rolling live ring.
    Q_PROPERTY(QObject* fileReplay READ fileReplay WRITE setFileReplay NOTIFY fileReplayChanged)
    Q_PROPERTY(int fileWindowStart READ fileWindowStart WRITE setFileWindowStart NOTIFY fileViewportChanged)
    Q_PROPERTY(int fileWindowColumns READ fileWindowColumns WRITE setFileWindowColumns NOTIFY fileViewportChanged)
    Q_PROPERTY(int fileSelectedColumn READ fileSelectedColumn WRITE setFileSelectedColumn NOTIFY fileViewportChanged)
public:
    explicit NavoKoggerEchogramItem(QQuickItem* parent=nullptr);
    QObject* decoder() const { return _decoder; }
    void setDecoder(QObject* source);
    qreal depthFrom() const {return _from;}
    qreal depthRange() const {return _range;}
    int paletteMode() const {return _palette;}
    qreal lowLevel() const {return _low;}
    qreal highLevel() const {return _high;}
    qreal gain() const {return _gain;}
    qreal noiseFloor() const {return _noiseFloor;}
    bool frozen() const {return _frozen;}
    bool showBottomTrack() const {return _showBottom;}
    bool upstreamRaster() const {return _upstreamRaster;}
    bool upstreamCompensated() const {return _upstreamCompensated;}
    int columnCount() const;
    QObject* fileReplay() const { return _fileReplay; }
    void setFileReplay(QObject* replay);
    int fileWindowStart() const { return _fileWindowStart; }
    void setFileWindowStart(int start);
    int fileWindowColumns() const { return _fileWindowColumns; }
    void setFileWindowColumns(int count);
    int fileSelectedColumn() const { return _fileSelectedColumn; }
    void setFileSelectedColumn(int column);
    void setDepthFrom(qreal v);
    void setDepthRange(qreal v);
    void setPaletteMode(int v);
    void setLowLevel(qreal v);
    void setHighLevel(qreal v);
    void setGain(qreal v);
    void setNoiseFloor(qreal v);
    void setFrozen(bool v);
    void setShowBottomTrack(bool v);
    void setUpstreamRaster(bool v);
    void setUpstreamCompensated(bool v);
    Q_INVOKABLE void resetColumns();
    Q_INVOKABLE void setBottomDepth(quint64 sequence, double depth);
    Q_INVOKABLE QVariantMap inspectAt(qreal x, qreal y) const;
    void paint(QPainter* painter) override;
protected:
    void geometryChange(const QRectF& newGeometry,const QRectF& oldGeometry) override;
signals:
    void decoderChanged();
    void displayChanged();
    void frozenChanged();
    void columnsChanged();
    void fileReplayChanged();
    void fileViewportChanged();
private:
    struct Column {
        QByteArray bytes;
        quint64 sequence=0;
        quint16 resolutionMm=0;
        quint16 absoluteOffset=0;
        quint8 version=0;
        double bottom=qQNaN();
    };
    mutable QMutex _mutex;
    QVector<Column> _columns;
    QPointer<NavoKoggerDecoder> _decoder;
    QTimer _frameTimer;
    QTimer _fileLoadTimer;
    QPointer<QObject> _fileReplay;
    int _fileWindowStart=0;
    int _fileWindowColumns=1;
    int _fileSelectedColumn=0;
    int _fileTotalColumns=0;
    QHash<int,Column> _fileColumns;
    QQueue<int> _fileCacheOrder;
    QSet<int> _fileAttempted; // Avoid thrashing if one viewport exceeds the byte cache.
    int _fileCacheBytes=0;
    static constexpr int MaxFileCacheBytes=24*1024*1024;
    static constexpr int MaxFileCacheColumns=4096;
    int fileIndexAtPixel(int x,int imageWidth,int fileSize) const;
    void refreshFileViewport();
    void loadFileBatch();
    qreal _from=0, _range=50, _low=0, _high=100, _gain=1, _noiseFloor=0;
    int _palette=0;
    bool _frozen=false, _showBottom=true;
    bool _upstreamRaster=false, _upstreamCompensated=false;
    static constexpr int MaxRetainedColumns=4096;
    static constexpr int MaxRawCacheBytes=24*1024*1024;
    int _rawCacheBytes=0;
    void receiveColumn();
    void requestFrame();
};
