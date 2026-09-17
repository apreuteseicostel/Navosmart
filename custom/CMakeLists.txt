# NAVO SMART custom build overlay for QGroundControl
# V0.1 bootstrap. QGC upstream remains the application core.

message(STATUS "Building NAVO SMART custom overlay")

qt_add_resources(${PROJECT_NAME} "navosmart_qml"
    PREFIX "/qml"
    FILES
        qml/NavoDashboard.qml
)
