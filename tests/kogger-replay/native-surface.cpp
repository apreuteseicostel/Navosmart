#include "../../custom/kogger_native/navo_surface_mesh.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <iostream>
#include <stdexcept>
void require(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
int main(int argc,char**argv){
 QCoreApplication app(argc,argv);
 const LLARef reference(LLA(40.1616,44.4743,0));
 TileMap tiles;SurfaceTile tile(TileKey(0,0,3),QVector3D(0,0,0));tile.init(256,2,.1f);
 auto& points=tile.getHeightVerticesRef();auto& marks=tile.getHeightMarkVerticesRef();
 for(int i=0;i<points.size();++i){points[i].setZ(-float(3+i));marks[i]=HeightType::kTriangulation;}
 tile.updateHeightIndices();tiles.insert(TileKey(0,0,3),tile);
 auto mesh=navoNativeSurfaceMesh(tiles,reference);auto vertices=mesh.value("vertices").toList();
 require(vertices.size()==9 && mesh.value("indices").toList().size()==24,"native topology lost");
 auto origin=vertices[0].toList();require(std::abs(origin[0].toDouble()-40.1616)<1e-8 && std::abs(origin[1].toDouble()-44.4743)<1e-8,"NED origin misplaced");
 const auto a=points[3];const NED ned(a.x(),a.y(),-a.z());const LLA geo(&ned,&reference);
 const auto north=vertices[3].toList();
 // Export order follows topology, not original vertex order.
 bool found=false;for(const auto& v:vertices){auto p=v.toList();if(std::abs(p[0].toDouble()-geo.latitude)<1e-8 && std::abs(p[1].toDouble()-geo.longitude)<1e-8)found=true;}
 require(found && geo.longitude>reference.refLla.longitude,"east/north axes swapped");
 marks[0]=HeightType::kUndefined;tiles[TileKey(0,0,3)]=tile;
 require(navoNativeSurfaceMesh(tiles,reference).value("indices").toList().size()==21,"undefined vertex was rendered");
 points[0].setZ(qQNaN());marks[0]=HeightType::kTriangulation;tiles[TileKey(0,0,3)]=tile;
 require(navoNativeSurfaceMesh(tiles,reference).value("indices").toList().size()==21,"NaN depth was rendered");
 require(navoNativeSurfaceMesh(tiles,LLARef()).value("indices").toList().isEmpty(),"mesh exported without GPS origin");
 TileMap large;for(int i=0;i<128;i++){SurfaceTile t(TileKey(i,0,3),QVector3D(i*25.6,0,0));t.init(256,16,.1f);for(auto& p:t.getHeightVerticesRef())p.setZ(-5);for(auto& m:t.getHeightMarkVerticesRef())m=HeightType::kTriangulation;t.updateHeightIndices();large.insert(TileKey(i,0,3),t);}
 const auto capped=navoNativeSurfaceMesh(large,reference);
 require(capped.value("vertices").toList().size()<=8192 && capped.value("indices").toList().size()<=49152 && capped.value("truncated").toBool(),"surface export exceeded its budget");
 std::cout<<"PASS native surface topology, georeferencing, unknown/invalid rejection and bounded export\n";
}
