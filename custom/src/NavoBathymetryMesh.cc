#include "NavoBathymetryMesh.h"
#include <QVariantMap>
#include <QHash>
#include <QSet>
#include <QtMath>
#include <algorithm>
#include <limits>
#include <QFile>
#include <QDataStream>
#include <QCryptographicHash>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDir>
#include <cmath>

NavoBathymetryMesh::NavoBathymetryMesh(QObject* parent):QObject(parent){}

// Native Kogger surface -> the pre-existing NAVO Qt Quick 3D geometry contract.
// No re-triangulation, synthetic soundings, or mutations to the source Dataset.
bool NavoBathymetryMesh::loadNativeSurface(const QVariantMap& surface) {
    if(surface.value("version").toInt()!=1 ||
       surface.value("source").toString()!=QStringLiteral("kogger-native-surface")) return false;
    const auto points=surface.value("vertices").toList();
    const auto indices=surface.value("indices").toList();
    if(points.size()<3 || points.size()>8192 ||
       indices.size()<3 || indices.size()>49152 || indices.size()%3) return false;

    const auto first=points.first().toList();
    if(first.size()!=4) return false;
    bool okLat=false,okLon=false;
    const double lat0=first[0].toDouble(&okLat),lon0=first[1].toDouble(&okLon);
    if(!okLat || !okLon || !std::isfinite(lat0) || !std::isfinite(lon0) ||
       std::abs(lat0)>90 || std::abs(lon0)>180) return false;

    struct Point { double x,y,depth; int mark; };
    QVector<Point> converted;
    QVariantList vertices,triangles;
    converted.reserve(points.size());
    const double kEarthRadius=6378137.0, latRadians=qDegreesToRadians(lat0);
    double minDepth=std::numeric_limits<double>::infinity();
    double maxDepth=-std::numeric_limits<double>::infinity();
    for(const auto& item:points) {
        const auto p=item.toList();
        if(p.size()!=4) return false;
        bool a=false,b=false,c=false,d=false;
        const double lat=p[0].toDouble(&a),lon=p[1].toDouble(&b),depth=p[2].toDouble(&c);
        const int mark=p[3].toInt(&d);
        if(!a||!b||!c||!d||!std::isfinite(lat)||!std::isfinite(lon)||!std::isfinite(depth) ||
           std::abs(lat)>90||std::abs(lon)>180||depth<=0||depth>1000||mark<1||mark>3)
            return false;
        // Local scene is X=east, Y=north, Z=-depth; QQuick3D maps X,Y to X,-Z.
        const double east=qDegreesToRadians(lon-lon0)*std::cos(latRadians)*kEarthRadius;
        const double north=qDegreesToRadians(lat-lat0)*kEarthRadius;
        if(!std::isfinite(east)||!std::isfinite(north) ||
           std::abs(east)>10000||std::abs(north)>10000) return false;
        converted.push_back({east,north,depth,mark});
        // Kogger surface mark kTriangulation is derived, NOT proof of a direct
        // sonar measurement; never label these exported vertices "measured".
        const double displayConfidence=mark==3 ? 0.75 : mark==2 ? 0.60 : 0.35;
        vertices.append(QVariantMap{{"x",east},{"y",north},{"z",-depth},
                                    {"depth",depth},{"measured",false},
                                    {"confidence",displayConfidence},
                                    {"nativeMark",mark}});
        minDepth=std::min(minDepth,depth);
        maxDepth=std::max(maxDepth,depth);
    }
    for(int t=0;t<indices.size();t+=3) {
        bool a=false,b=false,c=false;
        const int i=indices[t].toInt(&a),j=indices[t+1].toInt(&b),k=indices[t+2].toInt(&c);
        if(!a||!b||!c || i<0||j<0||k<0 ||
           i>=converted.size()||j>=converted.size()||k>=converted.size() ||
           i==j||j==k||i==k) return false;
        const auto& p=converted[i]; const auto& q=converted[j]; const auto& r=converted[k];
        const double twiceArea=(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x);
        if(!std::isfinite(twiceArea) || std::abs(twiceArea)<0.00001) return false;
        const auto edge2=[](const Point& a,const Point& b){
            const double dx=a.x-b.x,dy=a.y-b.y;
            return dx*dx+dy*dy;
        };
        // Reject huge geographic jumps instead of filling unknown lake areas.
        if(edge2(p,q)>40000 || edge2(q,r)>40000 || edge2(r,p)>40000) return false;
        triangles.append(QVariant(QVariantList{i,j,k}));
    }

    // Commit atomically so a malformed recording cannot replace a valid scene.
    _vertices=std::move(vertices);
    _triangles=std::move(triangles);
    _originLat=lat0; _originLon=lon0;
    _minDepth=minDepth; _maxDepth=maxDepth;
    _measuredCount=0; _interpolatedCount=_vertices.size();
    _lodLevel=0;
    _cacheKey=QStringLiteral("kogger-native-runtime");
    emit meshChanged();
    return true;
}
void NavoBathymetryMesh::clear(){_vertices.clear();_triangles.clear();_cacheKey.clear();_originLat=_originLon=0;_minDepth=_maxDepth=0;_measuredCount=_interpolatedCount=0;emit meshChanged();}

static QString measurementKey(const QVariantList& samples,double gridSizeM,double maxGapM,int lodLevel){
    // Cache identity must change for any measurement or mesh parameter change.
    // Hashing only first/last samples allowed stale meshes when middle sonar data changed.
    QCryptographicHash hh(QCryptographicHash::Sha256);
    hh.addData("NAVO-BATHYMETRY-MESH-V3|");
    hh.addData(QByteArray::number(gridSizeM,'g',17)); hh.addData("|");
    hh.addData(QByteArray::number(maxGapM,'g',17)); hh.addData("|");
    hh.addData(QByteArray::number(qBound(0,lodLevel,3))); hh.addData("|");
    hh.addData(QByteArray::number(samples.size()));
    for (const QVariant& v : samples) {
        const QVariantMap sm = v.toMap();
        hh.addData("|"); hh.addData(QByteArray::number(sm.value("lat").toDouble(),'g',17));
        hh.addData(","); hh.addData(QByteArray::number(sm.value("lon").toDouble(),'g',17));
        hh.addData(","); hh.addData(QByteArray::number(sm.value("depth").toDouble(),'g',17));
        // Include optional sonar metadata when present so corrected samples invalidate cache too.
        if (sm.contains("timestamp")) { hh.addData(",t="); hh.addData(sm.value("timestamp").toString().toUtf8()); }
        if (sm.contains("confidence")) { hh.addData(",c="); hh.addData(QByteArray::number(sm.value("confidence").toDouble(),'g',17)); }
        if (sm.contains("hardness")) { hh.addData(",h="); hh.addData(QByteArray::number(sm.value("hardness").toDouble(),'g',17)); }
        if (sm.contains("bottomEcho")) { hh.addData(",e="); hh.addData(QByteArray::number(sm.value("bottomEcho").toDouble(),'g',17)); }
    }
    return QString::fromLatin1(hh.result().toHex());
}

bool NavoBathymetryMesh::buildCached(const QVariantList& samples,double gridSizeM,double maxGapM,int lodLevel){
    const QString key=measurementKey(samples,gridSizeM,maxGapM,lodLevel);
    const QString folder=QStandardPaths::writableLocation(QStandardPaths::CacheLocation)+"/navo-mesh";
    const QString path=folder+"/"+key+".bin";
    if(loadCache(path,key)) return true;
    if(!build(samples,gridSizeM,maxGapM,lodLevel)) return false;
    if(QDir().mkpath(folder)) {
        saveCache(path);
        // Cache is disposable; bound disk growth as new sonar measurements arrive.
        QDir dir(folder); const auto files=dir.entryInfoList({"*.bin"},QDir::Files,QDir::Time);
        for(int i=16;i<files.size();++i) QFile::remove(files[i].absoluteFilePath());
    }
    return true;
}

bool NavoBathymetryMesh::build(const QVariantList& samples,double gridSizeM,double maxGapM,int lodLevel){
    clear(); if(samples.size()<3 || !qIsFinite(gridSizeM) || !qIsFinite(maxGapM) || gridSizeM<0.5 || maxGapM<0 || maxGapM/gridSizeM>16) return false;
    _lodLevel=qBound(0,lodLevel,3);
    _cacheKey=measurementKey(samples,gridSizeM,maxGapM,lodLevel);
    QVariantMap first=samples.first().toMap(); _originLat=first.value("lat").toDouble(); _originLon=first.value("lon").toDouble();
    const double R=6378137.0, lat0=qDegreesToRadians(_originLat), cell=qMax(0.5,gridSizeM*qPow(2.0,_lodLevel));
    struct Raw{double x,y,d;}; QVector<Raw> raw; raw.reserve(samples.size());
    for(const QVariant& v:samples){auto s=v.toMap();bool a,b,c;double lat=s.value("lat").toDouble(&a),lon=s.value("lon").toDouble(&b),d=s.value("depth").toDouble(&c);if(!a||!b||!c||!qIsFinite(lat)||!qIsFinite(lon)||qAbs(lat)>90||qAbs(lon)>180||!qIsFinite(d)||d<0)continue;raw.push_back({qDegreesToRadians(lon-_originLon)*qCos(lat0)*R,qDegreesToRadians(lat-_originLat)*R,d});}
    if(raw.size()<3)return false;
    QVector<double> ds;for(auto&r:raw)ds<<r.d;std::sort(ds.begin(),ds.end());double median=ds[ds.size()/2];QVector<double> dev;for(double d:ds)dev<<qAbs(d-median);std::sort(dev.begin(),dev.end());double mad=dev[dev.size()/2];double limit=qMax(0.75,4.5*1.4826*mad);
    struct Acc{double sx=0,sy=0,sd=0;int n=0;};QHash<QString,Acc> bins;
    _minDepth=std::numeric_limits<double>::infinity();_maxDepth=-_minDepth;
    for(auto&r:raw){if(qAbs(r.d-median)>limit)continue;int gx=qRound(r.x/cell),gy=qRound(r.y/cell);QString k=QString::number(gx)+":"+QString::number(gy);auto a=bins.value(k);a.sx+=r.x;a.sy+=r.y;a.sd+=r.d;a.n++;bins.insert(k,a);_minDepth=qMin(_minDepth,r.d);_maxDepth=qMax(_maxDepth,r.d);}
    if(bins.size()<3){clear();return false;}
    struct Cell{double x,y,d,confidence;bool measured;int n;};QHash<QString,Cell> cells;
    for(auto it=bins.cbegin();it!=bins.cend();++it){auto a=it.value();cells.insert(it.key(),{a.sx/a.n,a.sy/a.n,a.sd/a.n,qMin(1.0,0.45+0.15*a.n),true,a.n});}
    const int reach=qMax(1,qFloor(maxGapM/cell));
    // Spatially indexed interpolation: each candidate cell only inspects measured
    // neighbours inside the local grid window instead of rescanning every bin.
    // Complexity becomes proportional to candidates * local neighbourhood, rather
    // than candidates * all sonar samples, which is critical for large lakes.
    QHash<QString,Cell> additions;
    QSet<QString> candidates;
    for(auto it=bins.cbegin();it!=bins.cend();++it){
        const auto parts=it.key().split(':'); const int gx=parts[0].toInt(),gy=parts[1].toInt();
        for(int oy=-reach;oy<=reach;oy++) for(int ox=-reach;ox<=reach;ox++){
            if(!ox&&!oy) continue;
            const QString k=QString::number(gx+ox)+":"+QString::number(gy+oy);
            if(!cells.contains(k)) candidates.insert(k);
        }
    }
    for(const QString& k : candidates){
        const auto parts=k.split(':'); const int cx=parts[0].toInt(),cy=parts[1].toInt();
        double sw=0.0, sd=0.0; int neighbours=0;
        for(int ny=cy-reach;ny<=cy+reach;ny++) for(int nx=cx-reach;nx<=cx+reach;nx++){
            const int dx=nx-cx, dy=ny-cy;
            if(!dx&&!dy) continue;
            const double dist=qSqrt(double(dx*dx+dy*dy))*cell;
            if(dist>maxGapM||dist<0.01) continue;
            const QString nk=QString::number(nx)+":"+QString::number(ny);
            auto jt=bins.constFind(nk); if(jt==bins.cend()) continue;
            const double w=1.0/(dist*dist);
            sw+=w; sd+=w*(jt.value().sd/jt.value().n); neighbours++;
        }
        if(neighbours>=3&&sw>0.0)
            additions.insert(k,{cx*cell,cy*cell,sd/sw,qMin(0.7,0.2+0.1*neighbours),false,0});
    }
    for(auto it=additions.cbegin();it!=additions.cend();++it) cells.insert(it.key(),it.value());
    QHash<QString,int> index;
    for(auto it=cells.cbegin();it!=cells.cend();++it){auto a=it.value();QVariantMap p{{"x",a.x},{"y",a.y},{"z",-a.d},{"depth",a.d},{"samples",a.n},{"measured",a.measured},{"confidence",a.confidence}};index.insert(it.key(),_vertices.size());_vertices<<p;if(a.measured)_measuredCount++;else _interpolatedCount++;}
    for(auto it=cells.cbegin();it!=cells.cend();++it){auto p=it.key().split(':');int x=p[0].toInt(),y=p[1].toInt();QString k00=it.key(),k10=QString::number(x+1)+":"+QString::number(y),k01=QString::number(x)+":"+QString::number(y+1),k11=QString::number(x+1)+":"+QString::number(y+1);if(index.contains(k10)&&index.contains(k01)&&index.contains(k11)){_triangles<<QVariant(QVariantList{index[k00],index[k10],index[k11]})<<QVariant(QVariantList{index[k00],index[k11],index[k01]});}}
    emit meshChanged();return !_triangles.isEmpty();
}

bool NavoBathymetryMesh::saveCache(const QString& path) const{
    QSaveFile f(path); if(!f.open(QIODevice::WriteOnly)) return false;
    QDataStream s(&f); s.setVersion(QDataStream::Qt_6_8);
    s<<quint32(0x4E564D33)<<quint16(2)<<_cacheKey<<qint32(_lodLevel)<<_originLat<<_originLon<<_minDepth<<_maxDepth<<qint32(_measuredCount)<<qint32(_interpolatedCount)<<_vertices<<_triangles;
    if(s.status()!=QDataStream::Ok) { f.cancelWriting(); return false; }
    return f.commit();
}
bool NavoBathymetryMesh::loadCache(const QString& path,const QString& expectedKey){ QFile f(path);if(!f.open(QIODevice::ReadOnly))return false;QDataStream s(&f);s.setVersion(QDataStream::Qt_6_8);quint32 magic;quint16 ver;qint32 lod,mc,ic;QString key;QVariantList v,t;double la,lo,mi,ma;s>>magic>>ver>>key>>lod>>la>>lo>>mi>>ma>>mc>>ic>>v>>t;if(s.status()!=QDataStream::Ok||magic!=0x4E564D33||ver!=2||(!expectedKey.isEmpty()&&key!=expectedKey))return false;_cacheKey=key;_lodLevel=lod;_originLat=la;_originLon=lo;_minDepth=mi;_maxDepth=ma;_measuredCount=mc;_interpolatedCount=ic;_vertices=v;_triangles=t;emit meshChanged();return true;}
