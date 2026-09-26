message(STATUS "NAVO SMART: loading custom QGroundControl overlay")

set_property(DIRECTORY ${CMAKE_SOURCE_DIR} APPEND PROPERTY COMPILE_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="CustomPlugin.h"
    CUSTOMCLASS=CustomPlugin
)

qt_add_library(NavoSmartModule STATIC)
qt_add_qml_module(NavoSmartModule
    URI NavoSmart
    VERSION 1.0
    RESOURCE_PREFIX /qml
    IMPORTS
        QGroundControl
        QGroundControl.Controllers
        QGroundControl.Controls
        QGroundControl.FlightDisplay
        QGroundControl.FlightMap
        QtQuick3D
    QML_FILES
        qml/NavoDashboard.qml
        qml/NavoMap.qml
        qml/NavoTelemetryCard.qml
        qml/NavoModeButton.qml
        qml/NavoWaypointEditor.qml
        qml/NavoWaypointDetails.qml
        qml/NavoWaypointMapOverlay.qml
        qml/NavoActualTrack.qml
        qml/NavoBaitingController.qml
        qml/NavoBaitingPanel.qml
        qml/NavoHopperBridge.qml
        qml/NavoSonarCard.qml
        qml/NavoSonarFullScreen.qml
        qml/NavoCameraPip.qml
        qml/NavoSafetyCard.qml
        qml/NavoFailsafeController.qml
        qml/NavoFailsafePanel.qml
        qml/NavoDigitalAnchor.qml
        qml/NavoAreaScan.qml
        qml/NavoSonarRecorder.qml
        qml/NavoSonarMapping.qml
        qml/NavoMyLakes.qml
        qml/NavoSonarEthernet.qml
        qml/NavoCameraEthernet.qml
        qml/NavoEthernetSettings.qml
        qml/NavoEthernetIndicator.qml
        qml/NavoVideoPlayer.qml
        qml/NavoCameraFullScreen.qml
        qml/NavoBathymetryModel.qml
        qml/NavoBathymetry3D.qml
        qml/NavoScanCoordinator.qml
        qml/NavoFishingSpots.qml
        qml/NavoBathymetryOverlay.qml
        qml/NavoBathymetryHDOverlay.qml
        qml/NavoBathymetryHDModel.qml
        qml/NavoAreaScanOverlay.qml
        qml/NavoAreaDrawOverlay.qml
        qml/NavoMissionUploader.qml
        qml/NavoFishDetections.qml
        qml/NavoFishOverlay.qml
        qml/NavoFishDetector.qml
        qml/NavoEnergyGuard.qml
        qml/NavoActionSequence.qml
        qml/NavoSafetyManager.qml
        qml/NavoBoatStatus.qml
        qml/NavoHeadingCompass.qml
    RESOURCES
        icons/map.svg
        icons/sonar.svg
        icons/scan.svg
        icons/fish.svg
        icons/lake.svg
        icons/camera.svg
        icons/cube.svg
        icons/bait.svg
        icons/shield.svg
        icons/settings.svg
        icons/home.svg
        icons/lan.svg
        icons/nano.svg
        icons/autopilot.svg
        icons/speed.svg
        icons/battery.svg
        icons/temp.svg
        icons/satellite.svg
        icons/mode.svg
        icons/target.svg
        icons/mission.svg
        icons/zoom-in.svg
        icons/zoom-out.svg
        icons/center.svg
        icons/boat.svg
        icons/ruler.svg
        icons/fullscreen.svg
    NO_PLUGIN
)

set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerDecoder.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerDecoder.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerTcpClient.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerTcpClient.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoMissionBridge.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoMissionBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoPersistence.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoPersistence.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoEthernetTransport.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoEthernetTransport.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoNanoTelemetry.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoNanoTelemetry.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoBathymetryMesh.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoBathymetryMesh.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoBathymetryGeometry.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoBathymetryGeometry.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoTrack3DGeometry.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoTrack3DGeometry.h
    CACHE INTERNAL "" FORCE
)
# Link both the QML module target and its generated resource target into the
# final QGC executable. Static-library linking alone can discard the raw QML
# resource object because no C++ symbol references it.
set(CUSTOM_LIBRARIES
    NavoSmartModule
    NavoSmartModule_resources_1
    CACHE INTERNAL "" FORCE
)
set(CUSTOM_INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/src CACHE INTERNAL "" FORCE)
