#include "navo_mosaic_provider.h"
#include "NavoKoggerService.h"

NavoKoggerService& NavoKoggerService::instance()
{
    static NavoKoggerService service;
    return service;
}

MosaicIndexProvider* navoMosaicIndexProvider()
{
    return &NavoKoggerService::instance().mosaicIndexProvider();
}
