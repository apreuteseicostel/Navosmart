#include "../../custom/kogger_native/navo_native_isobaths.h"
#include <QCoreApplication>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>

static void require(bool good, const char* why) { if(!good) throw std::runtime_error(why); }
int main(int argc,char**argv) {
    QCoreApplication app(argc,argv);
    const LLARef origin(LLA(40.1616,44.4743,0));
    QVector<QVector3D> pairs{
        QVector3D(0,0,-3.03f),QVector3D(10,0,-3.03f),
        QVector3D(0,0,-4.03f),QVector3D(0,10,-4.03f)
    };
    auto result = navoNativeIsobaths(pairs,origin,1.0);
    const auto segments=result.value("segments").toList();
    require(result.value("version").toInt()==1 && segments.size()==2, "native contour lines were lost");
    require(result.value("source").toString()=="kogger-native-isobaths", "wrong source");
    const auto north=segments[0].toList(),east=segments[1].toList();
    require(north.size()==5 && east.size()==5, "invalid schema");
    require(std::abs(north[0].toDouble()-40.1616)<1e-7, "wrong reference latitude");
    require(north[2].toDouble()>north[0].toDouble(), "N axis points south instead of north");
    require(east[3].toDouble()>east[1].toDouble(), "E axis points west instead of east");
    require(std::abs(north[4].toDouble()-3)<1e-5 && std::abs(east[4].toDouble()-4)<1e-5, "depth sign or 3 cm line offset incorrect");
    require(navoNativeIsobaths(pairs,LLARef(),1.0).value("segments").toList().isEmpty(), "invalid GPS origin was accepted");
    require(navoNativeIsobaths(pairs,origin,0.0).value("segments").toList().isEmpty(), "invalid step accepted");
    QVector<QVector3D> bad{
        QVector3D(qQNaN(),0,-3.03f),QVector3D(1,0,-3.03f),
        QVector3D(0,0,0),QVector3D(1,0,0),
        QVector3D(0,0,-4.03f),QVector3D(1,0,-4.03f)
    };
    require(navoNativeIsobaths(bad,origin,1.0).value("segments").toList().size()==1,
            "NaN/zero-depth contour was exported");
    require(navoNativeIsobaths(pairs,origin,1.0,1).value("segments").toList().size()==1,
            "segment cap not respected");
    require(navoNativeIsobaths(pairs,origin,1.0,1).value("truncated").toBool(),
            "truncated flag missing");
    std::cout<<"PASS real Kogger contour NED-to-GPS, depth level, NaN/unknown rejection, bounded export\n";
    return 0;
}
