#include "../../custom/src/NavoBathymetryMesh.h"
#include <QCoreApplication>
#include <QVariantMap>
#include <QVariantList>
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <limits>

static void require(bool value,const char* why){if(!value)throw std::runtime_error(why);}
static QVariant coordinate(double lat,double lon,double depth,int mark) {
    return QVariant(QVariantList{lat,lon,depth,mark});
}
int main(int argc,char**argv){
    QCoreApplication app(argc,argv);
    NavoBathymetryMesh mesh;
    const double lat=40.1616, lon=44.4743;
    QVariantMap surface{
        {"version",1},{"source",QStringLiteral("kogger-native-surface")},
        {"vertices",QVariantList{
            coordinate(lat,lon,3.0,3),coordinate(lat,lon+.0001,5.0,3),
            coordinate(lat+.0001,lon,4.0,1)}},
        {"indices",QVariantList{0,1,2}},{"minDepth",3.0},{"maxDepth",5.0}
    };
    require(mesh.loadNativeSurface(surface),"valid Kogger surface rejected");
    require(mesh.vertices().size()==3 && mesh.triangles().size()==1,"Kogger topology changed");
    require(std::abs(mesh.minDepthM()-3.0)<1e-9 && std::abs(mesh.maxDepthM()-5.0)<1e-9,"depth extent changed");
    require(std::abs(mesh.originLatitude()-lat)<1e-9 && std::abs(mesh.originLongitude()-lon)<1e-9,"origin misplaced");
    const auto a=mesh.vertices()[0].toMap(),b=mesh.vertices()[1].toMap(),c=mesh.vertices()[2].toMap();
    require(std::abs(a.value("x").toDouble())<1e-6 && std::abs(a.value("y").toDouble())<1e-6,"origin is not local zero");
    require(b.value("x").toDouble()>0 && std::abs(b.value("y").toDouble())<1e-5,"east axis reversed");
    require(c.value("y").toDouble()>0 && std::abs(c.value("x").toDouble())<1e-5,"north axis reversed");
    require(std::abs(c.value("z").toDouble()+4.0)<1e-9,"negative-Z depth sign incorrect");
    require(!a.value("measured").toBool() && mesh.measuredVertexCount()==0,
            "derived Kogger terrain falsely labeled as directly measured");
    require(mesh.interpolatedVertexCount()==3,"source provenance missing");
    require(mesh.triangles().first().toList()==QVariantList({0,1,2}),"input indices lost");

    const auto original=mesh.vertices();
    auto invalid=surface;
    invalid["source"]=QStringLiteral("untrusted-surface");
    require(!mesh.loadNativeSurface(invalid) && mesh.vertices()==original,"untrusted surface mutated active geometry");
    invalid=surface;invalid["vertices"]=QVariantList{
        coordinate(lat,lon,3,3),coordinate(lat,lon+.0001,5,3),
        coordinate(lat+.0001,lon,qQNaN(),1)};
    require(!mesh.loadNativeSurface(invalid),"NaN depth accepted");
    invalid=surface;invalid["vertices"]=QVariantList{
        coordinate(lat,lon,3,3),coordinate(lat,lon+.0001,0,3),
        coordinate(lat+.0001,lon,4,1)};
    require(!mesh.loadNativeSurface(invalid),"unknown zero depth rendered");
    invalid=surface;invalid["vertices"]=QVariantList{
        coordinate(lat,lon,3,3),coordinate(lat,lon+.0001,5,0),
        coordinate(lat+.0001,lon,4,1)};
    require(!mesh.loadNativeSurface(invalid),"undefined vertex mark accepted");
    invalid=surface;invalid["indices"]=QVariantList{0,1,3};
    require(!mesh.loadNativeSurface(invalid),"out-of-range index accepted");
    invalid=surface;invalid["indices"]=QVariantList{0,1,1};
    require(!mesh.loadNativeSurface(invalid),"degenerate triangle accepted");
    invalid=surface;invalid["vertices"]=QVariantList{
        coordinate(lat,lon,3,3),coordinate(lat,lon+.0001,5,3),
        coordinate(lat+1,lon,4,1)};
    require(!mesh.loadNativeSurface(invalid),"distant unscanned lake area triangulated");
    require(mesh.vertices()==original,"rejected input replaced valid terrain");

    QVariantList raw;
    for(int y=0;y<3;y++)for(int x=0;x<3;x++)
        raw.append(QVariantMap{{"lat",lat+y*2.0/111320.0},
                               {"lon",lon+x*2.0/(111320.0*std::cos(lat*3.141592653589793/180.0))},
                               {"depth",3.0+0.1*x+0.1*y}});
    require(mesh.build(raw,2.0,2.0,0),"existing sample-based 3D fallback failed");
    require(mesh.vertices().size()>0 && mesh.triangles().size()>0,
            "existing 3D fallback topology lost");
    std::cout<<"PASS native Kogger 3D topology, ENU axes, depths, source provenance, corrupt rejection and sample fallback\n";
}
