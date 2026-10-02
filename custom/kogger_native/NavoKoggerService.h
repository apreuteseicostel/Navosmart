#pragma once
#include "../../third_party/KoggerApp/src/dataset.h"
#include "../../third_party/KoggerApp/src/mosaic_index_provider.h"

// Central NAVO owner for the native Kogger dataset and mosaic geometry.
// Constructed once; the QML bridge and Dataset mosaic hook share its lifetime.
class NavoKoggerService final {
public:
    static NavoKoggerService& instance();
    Dataset& dataset() { return dataset_; }
    MosaicIndexProvider& mosaicIndexProvider() { return mosaicIndexProvider_; }
    NavoKoggerService(const NavoKoggerService&) = delete;
    NavoKoggerService& operator=(const NavoKoggerService&) = delete;
private:
    NavoKoggerService() : mosaicIndexProvider_(6200) {}
    Dataset dataset_;
    MosaicIndexProvider mosaicIndexProvider_;
};
