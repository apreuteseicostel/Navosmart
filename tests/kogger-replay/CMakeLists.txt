cmake_minimum_required(VERSION 3.16)
project(NavoKoggerReplay LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Concurrent Sql Network Qml)
add_executable(navo-kogger-replay replay.cpp ../../custom/src/NavoKoggerDecoder.cc ../../custom/src/NavoKoggerDecoder.h ../../custom/src/NavoKoggerReplay.cc ../../custom/src/NavoKoggerReplay.h)
target_sources(navo-kogger-replay PRIVATE
    ../../custom/src/NavoPersistence.cc
    ../../custom/src/NavoPersistence.h
    ../../custom/src/NavoEthernetTransport.cc
    ../../custom/src/NavoEthernetTransport.h
    ../../custom/src/NavoKoggerChartBridge.h
    ../../custom/kogger_native/epoch.cpp
    ../../custom/kogger_native/dataset.cpp
    ../../custom/kogger_native/navo_mosaic_provider.cpp
    ../../third_party/KoggerApp/src/dataset.h
    ../../third_party/KoggerApp/src/data_interpolator.cpp
    ../../third_party/KoggerApp/src/black_stripes_processor.cpp
    ../../third_party/KoggerApp/src/mosaic_index_provider.cpp
)
include(../../custom/kogger_native/processors.cmake)
target_sources(navo-kogger-replay PRIVATE ${NAVO_KOGGER_PROCESSOR_SOURCES})
target_include_directories(navo-kogger-replay PRIVATE ${NAVO_KOGGER_PROCESSOR_INCLUDES})
target_link_libraries(navo-kogger-replay PRIVATE Qt6::Core Qt6::Gui Qt6::Concurrent Qt6::Sql Qt6::Network Qt6::Qml)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml Test)
add_executable(navo-sonar-ui-replay ui-replay.cpp)
target_link_libraries(navo-sonar-ui-replay PRIVATE Qt6::Quick Qt6::Qml Qt6::Test)
file(GLOB NAVO_TEST_ICONS "../../custom/icons/*.svg")
qt_add_resources(navo-sonar-ui-replay navo-test-icons PREFIX "/qml/NavoSmart" BASE "../../custom" FILES ${NAVO_TEST_ICONS})
