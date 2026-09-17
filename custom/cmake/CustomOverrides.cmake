# NAVO SMART custom QGroundControl build overrides
# V0.1 - Romanian bait boat ground station

set(QGC_APP_NAME "NAVO SMART" CACHE STRING "App Name" FORCE)
set(QGC_APP_DESCRIPTION "Navigatie inteligenta pentru navomodel de pescuit" CACHE STRING "App description" FORCE)
set(QGC_ORG_NAME "Pescarul lu peste" CACHE STRING "Organization" FORCE)
set(QGC_ORG_DOMAIN "navosmart.local" CACHE STRING "Organization domain" FORCE)
set(QGC_PACKAGE_NAME "ro.pescarullupeste.navosmart" CACHE STRING "Package identifier" FORCE)
set(QGC_ANDROID_PACKAGE_NAME "ro.pescarullupeste.navosmart" CACHE STRING "Android package identifier" FORCE)

# NAVO SMART is based on ArduPilot Rover/Boat. PX4 UI/factory is not required.
set(QGC_DISABLE_PX4_PLUGIN_FACTORY ON CACHE BOOL "Disable PX4 Plugin Factory" FORCE)
set(QGC_DISABLE_APM_PLUGIN_FACTORY OFF CACHE BOOL "Keep ArduPilot Plugin Factory" FORCE)

# Stable/release-oriented defaults.
set(QGC_STABLE_BUILD ON CACHE BOOL "Stable build" FORCE)
set(QGC_BUILD_TESTING OFF CACHE BOOL "Disable unit tests for Android app" FORCE)
