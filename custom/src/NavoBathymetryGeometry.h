#pragma once
#include <QQuick3DGeometry>
#include <QVariantList>
class NavoBathymetryGeometry : public QQuick3DGeometry {
    Q_OBJECT
    Q_PROPERTY(QVariantList vertices READ vertices WRITE setVertices NOTIFY dataChanged)
    Q_PROPERTY(QVariantList triangles READ triangles WRITE setTriangles NOTIFY dataChanged)
    Q_PROPERTY(float verticalExaggeration READ verticalExaggeration WRITE setVerticalExaggeration NOTIFY dataChanged)
public:
    explicit NavoBathymetryGeometry(QQuick3DObject* parent=nullptr);
    QVariantList vertices() const{return _vertices;} QVariantList triangles() const{return _triangles;} float verticalExaggeration()const{return _z;}
    void setVertices(const QVariantList& v); void setTriangles(const QVariantList& v); void setVerticalExaggeration(float v);
signals:void dataChanged();
private:void rebuild(); QVariantList _vertices,_triangles; float _z=2.f;
};
