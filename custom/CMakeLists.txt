# NAVO SMART custom build overlay for QGroundControl
# V0.3 - live map, telemetry and interactive fishing waypoints

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
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/NavoWaypointDetails.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/NavoWaypointMapOverlay.qml
    NO_PLUGIN
)

set(CUSTOM_LIBRARIES
    NavoSmartModule
    PARENT_SCOPE
)

set(CUSTOM_QT_COMPONENTS
    Core
    Location
    Positioning
    PARENT_SCOPE
)
