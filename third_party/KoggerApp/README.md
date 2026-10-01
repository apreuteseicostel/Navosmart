# KoggerApp experimental source import

Upstream: https://github.com/koggertech/KoggerApp
Upstream revision: 3a7f526681f5e0aa2285e8617f27e4cfee97d777 (master tree)
License: GPL-3.0; see LICENSE in this directory.

The imported source files are unmodified upstream copies for integration work.
The original BottomTrackProcessor depends on Dataset, Epoch, DataProcessor,
their definitions and related processors. This partial import is NOT built,
registered in CMake, or connected to NAVO sonar data yet.

Do not enable the upstream CMakeLists.txt without completing its dependencies
and reviewing GPL-3.0 obligations for any distributed combined application.
The NAVO standard sonar and H743 command path remain unchanged.
