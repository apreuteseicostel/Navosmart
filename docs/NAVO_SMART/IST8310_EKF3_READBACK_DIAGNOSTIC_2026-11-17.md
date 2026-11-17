# NAVO SMART — GNSS/IST8310/EKF3 diagnostic readback (17 November 2026)

## Reproduced symptoms and code diagnosis

The GNSS dialog in Draft #109 showed **"Busolă fără ID verificat"**
despite SYS_STATUS reporting a healthy 3D magnetometer, and
**"EKF3 yaw source: Parametru necitit"** while GPS1/UM982 dual-antenna
yaw was valid. Those are two **different assertions**:

- `MAV_SYS_STATUS_SENSOR_3D_MAG` reports the magnetometer **subsystem**
  health, not a specific physical IST8310 or I2C connector.
- `EK3_SRC1_YAW` previously only updated after unsolicited
  `PARAM_VALUE`; the component never requested the parameter.
- `COMPASS_DEV_ID` in a raw MAVLink floating `param_value` is not a
  trustworthy decimal 32-bit device ID. Decode the QGroundControl
  `Fact::rawValue()` (typed and mapped by QGC) instead.
- Valid UM982 GPS yaw displayed in the app is not proof that EKF3 on
  H743 currently uses the same source.

## Code changes

The heading component explicitly requests **read-only** parameter refresh
using QGroundControl `Vehicle::parameterManager()->refreshParameter()`.
One pass starts after connecting, and the operator can press
**Reverifică busola și EKF3** inside the GNSS diagnostic popup.

Requested names are `EK3_SRC1_YAW`, `EK3_SRC2_YAW`, `EK3_SRC3_YAW`,
`COMPASS_USE`, `COMPASS_USE2`, `COMPASS_USE3`,
`COMPASS_DEV_ID`, `COMPASS_DEV_ID2`, `COMPASS_DEV_ID3`,
`COMPASS_PRIO1_ID`, `COMPASS_PRIO2_ID`, `COMPASS_PRIO3_ID`.

- Values obtained through QGC Facts are shown separately from **actual**
  MAVLink `PARAM_VALUE` responses. A cached value is not displayed as
  proof of a new live response.
- Packed ArduPilot device IDs use busType = ID & 7, bus = (ID >> 3) & 31,
  address = (ID >> 8) & 255, deviceType = ID >> 16.
  **IST8310 = deviceType 0x0A**, expected I2C busType 1.
  The displayed bus number is firmware numbering, **not proof that the
  module is physically connected to the port labelled I2C1**.
- A nonzero compass ID or HEALTHY status **does not identify IST8310**.
  Priority IDs are shown only as configuration.
- `EK3_SRC1_YAW=3` means the configured GPS-with-magnetic-fallback
  source, **not proof that EKF switched to that sensor**.
- The existing conservative fallback still requires the explicit EKF3
  transition text, healthy compass, configured mode and correct yaw
  availability; this patch does not change navigation behavior.
- A single automatic request per connection and an explicit retry button
  avoid polling telemetry continuously. Parameter values are observed
  from the QGC manager; the refresh status times out after 6.5 seconds.
- Link loss, source vehicle switch and reconnect reset displayed state.

## Safety

No `PARAM_SET`, no ArduPilot writes, no reboot, compass calibration,
flight mode changes, RC channel changes, mission execution, hold/RTL
commands or servo operations.

**Acceptance on bench, propeller removed:**

1. Connect H743 with QGC parameters already loaded; wait for refresh.
2. Verify `EK3_SRC1_YAW` is numeric or explicitly shown as unanswered,
   not silently assumed to be 3.
3. Verify `COMPASS_DEV_ID{,2,3}` values and compare the reported
   IST8310 device type with Mission Planner or a direct ArduPilot dump.
4. Check `COMPASS_PRIO1_ID` refers to the sensor intended to be first.
   Do not change EKF parameters until configuration and calibration reviewed.
5. Unplug/disable only the sensor **on the bench**, verify diagnostic
   invalidation and no false fallback claim. Restore normal setup.
6. Disconnect/reconnect G20/GR01 and verify old cached values are
   distinguished from fresh live responses.
7. Read logs / EKF lane data before claiming that active EKF yaw
   source changed automatically after loss of GPS yaw.

## Tests

- Real Qt heading test using isolated QGC `ParameterManager`/Fact
  stubs checks requested names, that no writes are issued, device ID
  decoding, cache-versus-response state, compass priority, missing ID,
  and reconnect state reset.
- JavaScript audit checks UI wiring and no param writes.
- Android ARM64 compile and full NAVO core CI required on the exact PR SHA.

This branch is based on **Draft PR #109** and is not merged into main.
