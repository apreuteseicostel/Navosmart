#include "NavoTrack3DGeometry.h"
#include <QVector3D>
#include <QVariantMap>
#include <QtMath>

namespace {
float pointSegmentDistance(const QVector3D& p,const QVector3D& a,const QVector3D& b){
    QVector3D ab=b-a; float denom=QVector3D::dotProduct(ab,ab);
    if(denom<=1e-9f)return (p-a).length();
    float t=qBound(0.0f,QVector3D::dotProduct(p-a,ab)/denom,1.0f);
    return (p-(a+t*ab)).length();
}
void simplifyDP(const QVector<QVector3D>& in,int first,int last,float epsilon,QVector<bool>& keep){
    if(last<=first+1)return;
    float maxDist=-1.0f; int index=-1;
    for(int i=first+1;i<last;i++){float d=pointSegmentDistance(in[i],in[first],in[last]);if(d>maxDist){maxDist=d;index=i;}}
    if(index>first&&maxDist>epsilon){keep[index]=true;simplifyDP(in,first,index,epsilon,keep);simplifyDP(in,index,last,epsilon,keep);}
}
QVector<QVector3D> simplifyTrack(const QVector<QVector3D>& in,float epsilon){
    if(in.size()<3||epsilon<=0)return in;
    QVector<bool> keep(in.size(),false);keep[0]=true;keep[in.size()-1]=true;
    simplifyDP(in,0,in.size()-1,epsilon,keep);
    QVector<QVector3D> out;out.reserve(in.size());
    for(int i=0;i<in.size();i++)if(keep[i])out<<in[i];
    return out;
}
}
NavoTrack3DGeometry::NavoTrack3DGeometry(QQuick3DObject*p):QQuick3DGeometry(p){}
void NavoTrack3DGeometry::setPoints(const QVariantList&p){_p=p;rebuild();emit changed();}
void NavoTrack3DGeometry::setWidth(float w){_w=qMax(.03f,w);rebuild();emit changed();}
void NavoTrack3DGeometry::rebuild(){
    clear();if(_p.size()<2)return;
    QVector<QVector3D> raw;raw.reserve(_p.size());
    for(auto&v:_p){auto m=v.toMap();raw<<QVector3D(m["x"].toFloat(),m["y"].toFloat(),m["z"].toFloat());}
    // Geometry-aware Ramer-Douglas-Peucker simplification preserves turns and
    // depth/profile deviations instead of dropping every Nth point.
    const float epsilon=qMax(0.05f,_w*0.35f);
    QVector<QVector3D> p=simplifyTrack(raw,epsilon);if(p.size()<2)return;
    QByteArray vb(p.size()*2*3*sizeof(float),Qt::Uninitialized);float*o=reinterpret_cast<float*>(vb.data());
    for(int i=0;i<p.size();++i){QVector3D d=i+1<p.size()?p[i+1]-p[i]:p[i]-p[i-1];d.setY(0);if(d.lengthSquared()<1e-9f)d=QVector3D(0,0,1);else d.normalize();QVector3D side=QVector3D::crossProduct(QVector3D(0,1,0),d).normalized()*_w*.5f;for(auto v:{p[i]-side,p[i]+side}){*o++=v.x();*o++=v.y();*o++=v.z();}}
    QByteArray ib((p.size()-1)*6*sizeof(quint32),Qt::Uninitialized);auto*ix=reinterpret_cast<quint32*>(ib.data());
    for(int i=0;i<p.size()-1;i++){quint32 a=i*2,b=a+1,c=a+2,d=a+3;*ix++=a;*ix++=c;*ix++=b;*ix++=b;*ix++=c;*ix++=d;}
    setStride(3*sizeof(float));setVertexData(vb);setIndexData(ib);addAttribute(Attribute::PositionSemantic,0,Attribute::F32Type);addAttribute(Attribute::IndexSemantic,0,Attribute::U32Type);
}