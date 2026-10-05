#pragma once
#include <QVariantMap>
#include <QVariantList>
#include <algorithm>
#include "../../third_party/KoggerApp/src/dataset_defs.h"
#include "../../third_party/KoggerApp/src/data_processor/surface_tile.h"

// Export the original surface topology. Undefined/invalid vertices never
// acquire a fabricated depth, and N/E use the Dataset's original LLA origin.
inline QVariantMap navoNativeSurfaceMesh(const TileMap& tiles, const LLARef& reference) {
    QVariantList vertices, indices;
    double minimum=INFINITY, maximum=-INFINITY;
    bool truncated=false;
    auto keys=tiles.keys();
    std::sort(keys.begin(),keys.end(),[](const TileKey& a,const TileKey& b){
        if(a.zoom!=b.zoom)return a.zoom<b.zoom;
        if(a.x!=b.x)return a.x<b.x;
        return a.y<b.y;
    });
    if(reference.isInit && reference.refLla.isCoordinatesValid()) {
        for(const auto& key:keys) {
            const auto& tile=tiles[key];
            const auto& points=tile.getHeightVerticesCRef();
            const auto& marks=tile.getHeightMarkVerticesCRef();
            const auto& topology=tile.getHeightIndicesCRef();
            if(points.size()!=marks.size() || points.size()>8192)continue;
            QHash<int,int> remap;
            for(int t=0;t+2<topology.size();t+=3) {
                if(indices.size()+3>49152 || vertices.size()+3>8192) {truncated=true;break;}
                int original[3]={topology[t],topology[t+1],topology[t+2]};
                LLA geographic[3];bool valid=true;
                for(int c=0;c<3;++c) {
                    const int i=original[c];
                    if(i<0 || i>=points.size() || marks[i]==HeightType::kUndefined ||
                       !std::isfinite(points[i].x()) || !std::isfinite(points[i].y()) ||
                       !std::isfinite(points[i].z()) || points[i].z()>=0) {valid=false;break;}
                    const NED ned(points[i].x(),points[i].y(),-points[i].z());
                    geographic[c]=LLA(&ned,&reference);
                    if(!geographic[c].isCoordinatesValid() || std::abs(geographic[c].latitude)>90 ||
                       std::abs(geographic[c].longitude)>180) {valid=false;break;}
                }
                if(!valid)continue;
                for(int c=0;c<3;++c) {
                    const int i=original[c];
                    if(!remap.contains(i)) {
                        const double depth=-double(points[i].z());
                        remap.insert(i,vertices.size());
                        vertices.append(QVariant(QVariantList{geographic[c].latitude,geographic[c].longitude,depth,int(marks[i])}));
                        minimum=std::min(minimum,depth);maximum=std::max(maximum,depth);
                    }
                    indices.append(remap.value(i));
                }
            }
            if(truncated)break;
        }
    }
    return {{"version",1},{"source","kogger-native-surface"},{"vertices",vertices},{"indices",indices},
            {"minDepth",std::isfinite(minimum)?minimum:0},{"maxDepth",std::isfinite(maximum)?maximum:0},
            {"truncated",truncated}};
}
