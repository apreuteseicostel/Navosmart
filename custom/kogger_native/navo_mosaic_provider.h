#pragma once

class MosaicIndexProvider;

// NAVO-owned provider shared by the Dataset mosaic index calculations.
// The lifetime is explicit at module level rather than hidden in Dataset.
MosaicIndexProvider* navoMosaicIndexProvider();
