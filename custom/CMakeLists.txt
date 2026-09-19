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
    QML_FILES
        qml/NavoDashboard.qml
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
        qml/NavoLakePersistence.qml
        qml/NavoMyLakes.qml
        qml/NavoSonarEthernet.qml
        qml/NavoCameraEthernet.qml
        qml/NavoEthernetSettings.qml
        qml/NavoEthernetIndicator.qml
        qml/NavoVideoPlayer.qml
        qml/NavoCameraFullScreen.qml
        qml/NavoBathymetryModel.qml
        qml/NavoScanCoordinator.qml
        qml/NavoFishingSpots.qml
        qml/NavoBathymetryOverlay.qml
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
    SOURCES
        src/NavoEthernetTransport.cc
        src/NavoEthernetTransport.h
    NO_PLUGIN
)

set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerDecoder.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerDecoder.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerTcpClient.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoKoggerTcpClient.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoPersistence.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoPersistence.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoNanoTelemetry.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/NavoNanoTelemetry.h
    CACHE INTERNAL "" FORCE
)
set(CUSTOM_LIBRARIES NavoSmartModule CACHE INTERNAL "" FORCE)
set(CUSTOM_INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/src CACHE INTERNAL "" FORCE)
