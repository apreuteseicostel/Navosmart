#include "NavoBathymetryGeometry.h"
#include <QVector3D>
#include <QVariantMap>
#include <QTimer>
#include <QElapsedTimer>
NavoBathymetryGeometry::NavoBathymetryGeometry(QQuick3DObject* p):QQuick3DGeometry(p){rebuild();}
void NavoBathymetryGeometry::scheduleRebuild(){
    // QML updates vertices, triangles, depths and exaggeration separately.
    // Build the GPU buffer once after all same-event-loop property changes.
    if(_rebuildQueued)return;
    _rebuildQueued=true;
    QTimer::singleShot(0,this,[this](){
        _rebuildQueued=false;
        rebuild();
    });
}
void NavoBathymetryGeometry::setVertices(const QVariantList&v){if(_vertices==v)return;_vertices=v;scheduleRebuild();emit dataChanged();}
void NavoBathymetryGeometry::setTriangles(const QVariantList&v){if(_triangles==v)return;_triangles=v;scheduleRebuild();emit dataChanged();}
void NavoBathymetryGeometry::setVerticalExaggeration(float v){v=qBound(.25f,v,10.f);if(qFuzzyCompare(_z,v))return;_z=v;scheduleRebuild();emit dataChanged();}
void NavoBathymetryGeometry::setMinDepth(float v){if(qFuzzyCompare(_minDepth,v))return;_minDepth=v;scheduleRebuild();emit dataChanged();}
void NavoBathymetryGeometry::setMaxDepth(float v){if(qFuzzyCompare(_maxDepth,v))return;_maxDepth=v;scheduleRebuild();emit dataChanged();}
static QVector3D depthColor(float t,bool measured,float confidence){t=qBound(0.f,t,1.f);QVector3D a(.05f,.72f,.78f),b(.04f,.24f,.62f),c(.20f,.04f,.38f);QVector3D col=t<.5f?a*(1-2*t)+b*(2*t):b*(2-2*t)+c*(2*t-1);float q=measured?1.f:(.45f+.45f*qBound(0.f,confidence,1.f));return col*q;}
void NavoBathymetryGeometry::rebuild(){
 QElapsedTimer elapsed;elapsed.start();
 clear();
 if(_vertices.isEmpty()||_triangles.isEmpty()){
   _geometryBytes=0; _lastBuildMs=double(elapsed.nsecsElapsed())/1000000.0;
   ++_buildCount; emit performanceChanged();
   return;
 }
 const int stride=10*sizeof(float);QByteArray vb(_vertices.size()*stride,Qt::Uninitialized);float*out=reinterpret_cast<float*>(vb.data());QVector<QVector3D>pos;pos.reserve(_vertices.size());
 for(auto&v:_vertices){auto m=v.toMap();pos<<QVector3D(m["x"].toFloat(),m["z"].toFloat()*_z,-m["y"].toFloat());}
 QVector<QVector3D>n(pos.size());for(auto&t:_triangles){auto a=t.toList();if(a.size()!=3)continue;int i=a[0].toInt(),j=a[1].toInt(),k=a[2].toInt();if(i<0||j<0||k<0||i>=pos.size()||j>=pos.size()||k>=pos.size())continue;auto z=QVector3D::crossProduct(pos[j]-pos[i],pos[k]-pos[i]);n[i]+=z;n[j]+=z;n[k]+=z;}
 float span=qMax(.01f,_maxDepth-_minDepth);for(int i=0;i<pos.size();++i){auto m=_vertices[i].toMap();auto nn=n[i].lengthSquared()>0?n[i].normalized():QVector3D(0,1,0);auto col=depthColor((m["depth"].toFloat()-_minDepth)/span,m["measured"].toBool(),m["confidence"].toFloat());*out++=pos[i].x();*out++=pos[i].y();*out++=pos[i].z();*out++=nn.x();*out++=nn.y();*out++=nn.z();*out++=col.x();*out++=col.y();*out++=col.z();*out++=1.0f;}
 QByteArray ib(_triangles.size()*3*sizeof(quint32),Qt::Uninitialized);quint32*io=reinterpret_cast<quint32*>(ib.data());for(auto&t:_triangles)for(auto&i:t.toList())*io++=i.toUInt();
 QVector3D lo=pos.first(),hi=pos.first();for(const auto &p:pos){for(int axis=0;axis<3;++axis){lo[axis]=qMin(lo[axis],p[axis]);hi[axis]=qMax(hi[axis],p[axis]);}}setBounds(lo,hi);setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
 setStride(stride);setVertexData(vb);setIndexData(ib);addAttribute(Attribute::PositionSemantic,0,Attribute::F32Type);addAttribute(Attribute::NormalSemantic,3*sizeof(float),Attribute::F32Type);addAttribute(Attribute::ColorSemantic,6*sizeof(float),Attribute::F32Type);addAttribute(Attribute::IndexSemantic,0,Attribute::U32Type);
 _geometryBytes=int(vb.size()+ib.size());
 _lastBuildMs=double(elapsed.nsecsElapsed())/1000000.0;
 ++_buildCount; emit performanceChanged();
}
