#include "NavoBathymetryGeometry.h"
#include <QVector3D>
#include <QVariantMap>
#include <cstring>
NavoBathymetryGeometry::NavoBathymetryGeometry(QQuick3DObject* p):QQuick3DGeometry(p){rebuild();}
void NavoBathymetryGeometry::setVertices(const QVariantList&v){if(_vertices==v)return;_vertices=v;rebuild();emit dataChanged();}
void NavoBathymetryGeometry::setTriangles(const QVariantList&v){if(_triangles==v)return;_triangles=v;rebuild();emit dataChanged();}
void NavoBathymetryGeometry::setVerticalExaggeration(float v){v=qBound(0.25f,v,10.f);if(qFuzzyCompare(_z,v))return;_z=v;rebuild();emit dataChanged();}
void NavoBathymetryGeometry::rebuild(){
 clear(); if(_vertices.isEmpty()||_triangles.isEmpty())return;
 QByteArray vb;vb.resize(_vertices.size()*6*sizeof(float));float* out=reinterpret_cast<float*>(vb.data());
 QVector<QVector3D> pos;pos.reserve(_vertices.size());for(auto&v:_vertices){auto m=v.toMap();pos<<QVector3D(m["x"].toFloat(),-m["z"].toFloat()*_z,-m["y"].toFloat());}
 QVector<QVector3D> n(pos.size());for(auto&t:_triangles){auto a=t.toList();if(a.size()!=3)continue;int i=a[0].toInt(),j=a[1].toInt(),k=a[2].toInt();if(i<0||j<0||k<0||i>=pos.size()||j>=pos.size()||k>=pos.size())continue;auto z=QVector3D::crossProduct(pos[j]-pos[i],pos[k]-pos[i]);n[i]+=z;n[j]+=z;n[k]+=z;}
 for(int i=0;i<pos.size();++i){auto nn=n[i].lengthSquared()>0?n[i].normalized():QVector3D(0,1,0);*out++=pos[i].x();*out++=pos[i].y();*out++=pos[i].z();*out++=nn.x();*out++=nn.y();*out++=nn.z();}
 QByteArray ib;ib.resize(_triangles.size()*3*sizeof(quint32));quint32* io=reinterpret_cast<quint32*>(ib.data());for(auto&t:_triangles)for(auto&i:t.toList())*io++=i.toUInt();
 setStride(6*sizeof(float));setVertexData(vb);setIndexData(ib);addAttribute(Attribute::PositionSemantic,0,Attribute::F32Type);addAttribute(Attribute::NormalSemantic,3*sizeof(float),Attribute::F32Type);addAttribute(Attribute::IndexSemantic,0,Attribute::U32Type);
}
