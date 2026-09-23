#include "NavoBathymetryMesh.h"
#include <QVariantMap>
#include <QHash>
#include <QtMath>
#include <algorithm>
#include <limits>
#include <QFile>
#include <QDataStream>
#include <QCryptographicHash>

NavoBathymetryMesh::NavoBathymetryMesh(QObject* parent):QObject(parent){}
void NavoBathymetryMesh::clear(){_vertices.clear();_triangles.clear();_minDepth=_maxDepth=0;_measuredCount=_interpolatedCount=0;emit meshChanged();}

bool NavoBathymetryMesh::build(const QVariantList& samples,double gridSizeM,double maxGapM,int lodLevel){
    clear(); if(samples.size()<3) return false; _lodLevel=qBound(0,lodLevel,3);
    QCryptographicHash hh(QCryptographicHash::Sha256); hh.addData(QByteArray::number(samples.size())); hh.addData("|"); hh.addData(QByteArray::number(gridSizeM,'f',3)); hh.addData("|"); hh.addData(QByteArray::number(maxGapM,'f',3)); if(!samples.isEmpty()){auto a=samples.first().toMap(),b=samples.last().toMap();for(const auto& sm:{a,b}){hh.addData("|");hh.addData(QByteArray::number(sm.value("lat").toDouble(),'f',7));hh.addData(",");hh.addData(QByteArray::number(sm.value("lon").toDouble(),'f',7));hh.addData(",");hh.addData(QByteArray::number(sm.value("depth").toDouble(),'f',3));}} _cacheKey=QString::fromLatin1(hh.result().toHex());
    QVariantMap first=samples.first().toMap(); _originLat=first.value("lat").toDouble(); _originLon=first.value("lon").toDouble();
    const double R=6378137.0, lat0=qDegreesToRadians(_originLat), cell=qMax(0.5,gridSizeM*qPow(2.0,_lodLevel));
    struct Raw{double x,y,d;}; QVector<Raw> raw; raw.reserve(samples.size());
    for(const QVariant& v:samples){auto s=v.toMap();bool a,b,c;double lat=s.value("lat").toDouble(&a),lon=s.value("lon").toDouble(&b),d=s.value("depth").toDouble(&c);if(!a||!b||!c||!qIsFinite(d)||d<0)continue;raw.push_back({qDegreesToRadians(lon-_originLon)*qCos(lat0)*R,qDegreesToRadians(lat-_originLat)*R,d});}
    if(raw.size()<3)return false;
    QVector<double> ds;for(auto&r:raw)ds<<r.d;std::sort(ds.begin(),ds.end());double median=ds[ds.size()/2];QVector<double> dev;for(double d:ds)dev<<qAbs(d-median);std::sort(dev.begin(),dev.end());double mad=dev[dev.size()/2];double limit=qMax(0.75,4.5*1.4826*mad);
    struct Acc{double sx=0,sy=0,sd=0;int n=0;};QHash<QString,Acc> bins;
    _minDepth=std::numeric_limits<double>::infinity();_maxDepth=-_minDepth;
    for(auto&r:raw){if(qAbs(r.d-median)>limit)continue;int gx=qRound(r.x/cell),gy=qRound(r.y/cell);QString k=QString::number(gx)+":"+QString::number(gy);auto a=bins.value(k);a.sx+=r.x;a.sy+=r.y;a.sd+=r.d;a.n++;bins.insert(k,a);_minDepth=qMin(_minDepth,r.d);_maxDepth=qMax(_maxDepth,r.d);}
    if(bins.size()<3){clear();return false;}
    struct Cell{double x,y,d,confidence;bool measured;int n;};QHash<QString,Cell> cells;
    for(auto it=bins.cbegin();it!=bins.cend();++it){auto a=it.value();cells.insert(it.key(),{a.sx/a.n,a.sy/a.n,a.sd/a.n,qMin(1.0,0.45+0.15*a.n),true,a.n});}
    const int reach=qMax(1,qFloor(maxGapM/cell));
    QHash<QString,Cell> additions;
    for(auto it=bins.cbegin();it!=bins.cend();++it){auto parts=it.key().split(':');int gx=parts[0].toInt(),gy=parts[1].toInt();for(int oy=-reach;oy<=reach;oy++)for(int ox=-reach;ox<=reach;ox++){if(!ox&&!oy)continue;QString k=QString::number(gx+ox)+":"+QString::number(gy+oy);if(cells.contains(k)||additions.contains(k))continue;double sw=0,sd=0;int neighbours=0;for(auto jt=bins.cbegin();jt!=bins.cend();++jt){auto p=jt.key().split(':');int nx=p[0].toInt(),ny=p[1].toInt();double dist=qSqrt(qPow(nx-(gx+ox),2)+qPow(ny-(gy+oy),2))*cell;if(dist>maxGapM||dist<0.01)continue;double w=1.0/(dist*dist);sw+=w;sd+=w*(jt.value().sd/jt.value().n);neighbours++;}if(neighbours>=3&&sw>0)additions.insert(k,{(gx+ox)*cell,(gy+oy)*cell,sd/sw,qMin(0.7,0.2+0.1*neighbours),false,0});}}
    for(auto it=additions.cbegin();it!=additions.cend();++it)cells.insert(it.key(),it.value());
    QHash<QString,int> index;
    for(auto it=cells.cbegin();it!=cells.cend();++it){auto a=it.value();QVariantMap p{{"x",a.x},{"y",a.y},{"z",-a.d},{"depth",a.d},{"samples",a.n},{"measured",a.measured},{"confidence",a.confidence}};index.insert(it.key(),_vertices.size());_vertices<<p;if(a.measured)_measuredCount++;else _interpolatedCount++;}
    for(auto it=cells.cbegin();it!=cells.cend();++it){auto p=it.key().split(':');int x=p[0].toInt(),y=p[1].toInt();QString k00=it.key(),k10=QString::number(x+1)+":"+QString::number(y),k01=QString::number(x)+":"+QString::number(y+1),k11=QString::number(x+1)+":"+QString::number(y+1);if(index.contains(k10)&&index.contains(k01)&&index.contains(k11)){_triangles<<QVariantList{index[k00],index[k10],index[k11]}<<QVariantList{index[k00],index[k11],index[k01]};}}
    emit meshChanged();return !_triangles.isEmpty();
}

bool NavoBathymetryMesh::saveCache(const QString& path) const{ QFile f(path);if(!f.open(QIODevice::WriteOnly))return false;QDataStream s(&f);s.setVersion(QDataStream::Qt_6_8);s<<quint32(0x4E564D33)<<quint16(1)<<_cacheKey<<qint32(_lodLevel)<<_originLat<<_originLon<<_minDepth<<_maxDepth<<qint32(_measuredCount)<<qint32(_interpolatedCount)<<_vertices<<_triangles;return s.status()==QDataStream::Ok;}
bool NavoBathymetryMesh::loadCache(const QString& path,const QString& expectedKey){ QFile f(path);if(!f.open(QIODevice::ReadOnly))return false;QDataStream s(&f);s.setVersion(QDataStream::Qt_6_8);quint32 magic;quint16 ver;qint32 lod,mc,ic;QString key;QVariantList v,t;double la,lo,mi,ma;s>>magic>>ver>>key>>lod>>la>>lo>>mi>>ma>>mc>>ic>>v>>t;if(s.status()!=QDataStream::Ok||magic!=0x4E564D33||ver!=1||(!expectedKey.isEmpty()&&key!=expectedKey))return false;_cacheKey=key;_lodLevel=lod;_originLat=la;_originLon=lo;_minDepth=mi;_maxDepth=ma;_measuredCount=mc;_interpolatedCount=ic;_vertices=v;_triangles=t;emit meshChanged();return true;}
