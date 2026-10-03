cmake_minimum_required(VERSION 3.16)
project(NavoKoggerReplay LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui)
add_executable(navo-kogger-replay replay.cpp ../../custom/src/NavoKoggerDecoder.cc ../../custom/src/NavoKoggerDecoder.h)
target_sources(navo-kogger-replay PRIVATE
    ../../custom/kogger_native/epoch.cpp
    ../../custom/kogger_native/dataset.cpp
    ../../custom/kogger_native/navo_mosaic_provider.cpp
    ../../third_party/KoggerApp/src/dataset.h
    ../../third_party/KoggerApp/src/data_interpolator.cpp
    ../../third_party/KoggerApp/src/black_stripes_processor.cpp
    ../../third_party/KoggerApp/src/mosaic_index_provider.cpp
)
target_link_libraries(navo-kogger-replay PRIVATE Qt6::Core Qt6::Gui)
