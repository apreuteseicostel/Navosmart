#include "NavoBathymetryMesh.h"
#include <QVariantMap>
#include <QHash>
#include <QtMath>
#include <limits>

NavoBathymetryMesh::NavoBathymetryMesh(QObject* parent):QObject(parent){}

void NavoBathymetryMesh::clear(){_vertices.clear();_triangles.clear();_minDepth=_maxDepth=0;emit meshChanged();}

bool NavoBathymetryMesh::build(const QVariantList& samples,double gridSizeM,double maxGapM){
    clear(); if(samples.size()<3) return false;
    QVariantMap first=samples.first().toMap(); _originLat=first.value("lat").toDouble(); _originLon=first.value("lon").toDouble();
    const double R=6378137.0, lat0=qDegreesToRadians(_originLat), cell=qMax(0.5,gridSizeM);
    struct Acc{double sx=0,sy=0,sd=0;int n=0;}; QHash<QString,Acc> bins;
    _minDepth=std::numeric_limits<double>::infinity(); _maxDepth=-_minDepth;
    for(const QVariant& v:samples){auto s=v.toMap(); bool a,b,c; double lat=s.value("lat").toDouble(&a),lon=s.value("lon").toDouble(&b),d=s.value("depth").toDouble(&c); if(!a||!b||!c||!qIsFinite(d)||d<0)continue;
        double x=qDegreesToRadians(lon-_originLon)*qCos(lat0)*R, y=qDegreesToRadians(lat-_originLat)*R; int gx=qRound(x/cell),gy=qRound(y/cell); QString k=QString::number(gx)+":"+QString::number(gy);
        auto z=bins.value(k);z.sx+=x;z.sy+=y;z.sd+=d;z.n++;bins.insert(k,z);_minDepth=qMin(_minDepth,d);_maxDepth=qMax(_maxDepth,d);
    }
    if(bins.size()<3){clear();return false;}
    QHash<QString,int> index;
    for(auto it=bins.cbegin();it!=bins.cend();++it){auto a=it.value(); QVariantMap p{{"x",a.sx/a.n},{"y",a.sy/a.n},{"z",-a.sd/a.n},{"depth",a.sd/a.n},{"samples",a.n}};index.insert(it.key(),_vertices.size());_vertices<<p;}
    const int reach=qMax(1,qFloor(maxGapM/cell));
    Q_UNUSED(reach)
    // Conservative mesh: only create triangles where four directly adjacent measured grid cells exist.
    for(auto it=bins.cbegin();it!=bins.cend();++it){QStringList xy=it.key().split(':');int x=xy[0].toInt(),y=xy[1].toInt();QString k00=it.key(),k10=QString::number(x+1)+":"+QString::number(y),k01=QString::number(x)+":"+QString::number(y+1),k11=QString::number(x+1)+":"+QString::number(y+1);
        if(index.contains(k10)&&index.contains(k01)&&index.contains(k11)){_triangles<<QVariantList{index[k00],index[k10],index[k11]}<<QVariantList{index[k00],index[k11],index[k01]};}}
    emit meshChanged(); return !_triangles.isEmpty();
}
