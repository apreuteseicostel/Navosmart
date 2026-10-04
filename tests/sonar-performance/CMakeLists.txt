cmake_minimum_required(VERSION 3.16)
project(NavoSonarPerformance LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
add_executable(navo-sonar-performance sonar-performance.cpp)
target_link_libraries(navo-sonar-performance PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)

file(GLOB NAVO_ICONS "${CMAKE_CURRENT_SOURCE_DIR}/../../custom/icons/*.svg")
qt_add_resources(navo-sonar-performance navo-icons PREFIX "/qml/NavoSmart/icons" BASE "${CMAKE_CURRENT_SOURCE_DIR}/../../custom/icons" FILES ${NAVO_ICONS})

add_executable(navo-page-wiring page-wiring.cpp)
target_link_libraries(navo-page-wiring PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)
qt_add_resources(navo-page-wiring navo-page-icons PREFIX "/qml/NavoSmart/icons" BASE "${CMAKE_CURRENT_SOURCE_DIR}/../../custom/icons" FILES ${NAVO_ICONS})
