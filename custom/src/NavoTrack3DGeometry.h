#pragma once
#include <QQuick3DGeometry>
#include <QVariantList>
class NavoTrack3DGeometry:public QQuick3DGeometry{Q_OBJECT Q_PROPERTY(QVariantList points READ points WRITE setPoints NOTIFY changed) Q_PROPERTY(float width READ width WRITE setWidth NOTIFY changed)
public:explicit NavoTrack3DGeometry(QQuick3DObject*p=nullptr);QVariantList points()const{return _p;}float width()const{return _w;}void setPoints(const QVariantList&);void setWidth(float);
signals:void changed();private:void rebuild();QVariantList _p;float _w=.32f;};