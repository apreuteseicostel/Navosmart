# NAVO SMART custom build overlay for QGroundControl
# V0.2 - live map, telemetry and named fishing waypoints

message(STATUS "QGC: Adding NAVO SMART custom overlay")

qt_add_library(NavoSmartModule STATIC)
qgc_configure_target(NavoSmartModule)

qt_add_qml_module(NavoSmartModule
    URI NavoSmart
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/NavoDashboard.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/NavoTelemetryCard.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/NavoModeButton.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/NavoWaypointEditor.qml
    NO_PLUGIN
)

set(CUSTOM_LIBRARIES
    NavoSmartModule
    PARENT_SCOPE
)

set(CUSTOM_QT_COMPONENTS
    Core
    PARENT_SCOPE
)
