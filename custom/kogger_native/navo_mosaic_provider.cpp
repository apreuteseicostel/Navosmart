#include "navo_mosaic_provider.h"
#include "../../third_party/KoggerApp/src/mosaic_index_provider.h"

MosaicIndexProvider* navoMosaicIndexProvider()
{
    // Match the original KoggerApp Core mosaic capacity (6,200 tiles).
    static MosaicIndexProvider provider(6200);
    return &provider;
}
