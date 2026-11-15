# NAVO SMART — heading policy pending external compass validation
Date: 2026-11-15

## Hardware verified from public manufacturer/ArduPilot docs
- Genuine Mateksys H743-WING V3 has two inertial IMUs (ICM42688P, ICM42605) and a barometer; **no internal magnetometer**.
- It has external I2C1 DA1/CL1 and CAN connections for a compass.
- User-owned UM982 has two GNSS antennas, with about 33 cm measured baseline in prior tests; configure verified orientation offsets and test under open sky.
- Previous QGroundControl screenshot reported `Primary, External — IST8310 (I2C1)`; this is evidence of an **external sensor reported at that time**, not proof it is mounted, calibrated or currently being used.
- On 2026-10-28, the UM982 reported `UNIHEADINGA ... INSUFFICIENT_OBS`, `$GPTHS,,V` and invalid GNSS yaw 65535 indoors. A 3D position fix alone is **not** dual-antenna yaw.

## Dashboard policy introduced in this PR
1. Fresh valid `GPS_RAW_INT.yaw` from GPS1, else `GPS2_RAW.yaw` (MAVLink2; 1–36000 centidegrees; max age 3 s), and never `cog`.
2. When both yaw sources are missing/invalid/stale, display `HEADING --` and unknown orientation `?` on map. Do **not** infer heading from the apparent north-pointing graphical boat or from `vehicle.heading`.
3. Read-only H743/EKF heading remains in GNSS Diagnostics as `H743 / EKF (doar diagnostic)`; it is not selected for navigation graphics, since the external magnetometer has not been validated.
4. This changes QML and C++ display selection only; **it does not configure `EK3_SRC1_YAW`, change ArduPilot EKF, RC, motor/rudder, modes, or autonomous navigation permission**. Incorrect EKF yaw remains a boat-safety issue regardless of UI display.
5. A distinct compass fallback can be introduced **only after** physical presence, correct orientation, magnetic calibration, engine/ESC interference test and loss/recovery acceptance.

## Prior to any autonomous route
- Verify physical compass listing in QGroundControl Sensors/Compass. If `IST8310 (I2C1)` appears, locate the actual sensor/wire on DA1/CL1 and inspect `COMPASS_DEV_ID`, `COMPASS_PRIO`, `COMPASS_USE`, `COMPASS_ORIENT`; do not buy a duplicate before this check.
- Test UM982 outdoors with antenna master/slave separated >=30 cm and fixed relative to boat. Verify `GPS1_TYPE=25` and actual `SERIALx_PROTOCOL=5`. Validate baseline offsets `GPS1_MB_OFS_X/Y/Z`, EKF yaw source, and yaw updates at standstill while rotating **the whole fixed antenna assembly**. Do not infer heading quality solely from satellite count or RTK label.
- With a reliable UM982 heading and no commissioned magnetic compass, ArduPilot EKF3 YAW selection is normally `EK3_SRC1_YAW=2` (GPS). With a **validated external compass** it can use `=3` (GPS with compass fallback). These are review targets, not parameters to write blindly; first export the actual `.param` and inspect the Rover firmware.
- Use manual/G20 steering if yaw or GPS position is not reliable. A gyroscope can bridge brief intervals but accumulates yaw drift; compass gives orientation, **not GNSS location**. Never assume an extra compass restores autopilot HOME/RTL after true loss of position.

References:
- https://www.mateksys.com/?p=5159
- https://ardupilot.org/rover/docs/common-gps-for-yaw.html
- https://ardupilot.org/rover/docs/common-ekf-sources.html
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_HAL_ChibiOS/hwdef/MatekH743/hwdef.dat
