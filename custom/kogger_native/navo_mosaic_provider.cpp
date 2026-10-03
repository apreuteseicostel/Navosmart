#include "navo_mosaic_provider.h"
#include "NavoKoggerService.h"
MosaicIndexProvider* navoMosaicIndexProvider(){return &NavoKoggerService::instance().mosaicIndexProvider();}
