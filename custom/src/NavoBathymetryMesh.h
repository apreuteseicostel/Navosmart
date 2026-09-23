#pragma once
#include <QObject>
#include <QVariantList>
#include <QVector3D>

class NavoBathymetryMesh : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList vertices READ vertices NOTIFY meshChanged)
    Q_PROPERTY(QVariantList triangles READ triangles NOTIFY meshChanged)
    Q_PROPERTY(double minDepthM READ minDepthM NOTIFY meshChanged)
    Q_PROPERTY(double maxDepthM READ maxDepthM NOTIFY meshChanged)
    Q_PROPERTY(double originLatitude READ originLatitude NOTIFY meshChanged)
    Q_PROPERTY(double originLongitude READ originLongitude NOTIFY meshChanged)
    Q_PROPERTY(int measuredVertexCount READ measuredVertexCount NOTIFY meshChanged)
    Q_PROPERTY(int interpolatedVertexCount READ interpolatedVertexCount NOTIFY meshChanged)
    Q_PROPERTY(int lodLevel READ lodLevel NOTIFY meshChanged)
    Q_PROPERTY(QString cacheKey READ cacheKey NOTIFY meshChanged)
public:
    explicit NavoBathymetryMesh(QObject* parent=nullptr);
    Q_INVOKABLE bool build(const QVariantList& samples, double gridSizeM=2.0, double maxGapM=6.0, int lodLevel=0);
    Q_INVOKABLE bool saveCache(const QString& path) const;
    Q_INVOKABLE bool loadCache(const QString& path, const QString& expectedKey=QString());
    Q_INVOKABLE void clear();
    QVariantList vertices() const { return _vertices; }
    QVariantList triangles() const { return _triangles; }
    double minDepthM() const { return _minDepth; }
    double maxDepthM() const { return _maxDepth; }
    double originLatitude() const { return _originLat; }
    double originLongitude() const { return _originLon; }
    int measuredVertexCount() const { return _measuredCount; }
    int interpolatedVertexCount() const { return _interpolatedCount; }
    int lodLevel() const { return _lodLevel; }
    QString cacheKey() const { return _cacheKey; }
signals: void meshChanged();
private:
    QVariantList _vertices, _triangles;
    double _minDepth=0, _maxDepth=0, _originLat=0, _originLon=0;
    int _measuredCount=0, _interpolatedCount=0, _lodLevel=0;
    QString _cacheKey;
};
