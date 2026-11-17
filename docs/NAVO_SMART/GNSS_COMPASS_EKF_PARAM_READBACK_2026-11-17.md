# NAVO SMART — diagnostic H743 compass/EKF yaw: QGC parameter readback
Date: 17 Nov 2026. Child of Draft PR #109 (GNSS GPS1/GPS2 → compass → temporary H743 priority).

## Reproduced defect in the application

On the G20 diagnostic the application displayed:
- `EKF3 yaw source: Parametru necitit`
- `Busolă fără ID verificat; confirmă IST8310 pe I2C1`

The old `NavoGnssHeading` only populated `_ekfYawMode`,
`_compassUse` and `_compassDevIdPresent` by intercepting the
live MAVLink `PARAM_VALUE` stream. QGroundControl may load/restore those
parameters *before* NAVO's heading monitor is constructed, so the monitor
never receives those messages and keeps default values of -1. This is a
diagnostic readback deficiency, not evidence that the hardware failed.

`SYS_STATUS` with MAG PRESENT + ENABLED + HEALTHY is **aggregate
magnetometer telemetry**. It does NOT identify the sensor chip or the
I2C port. A usable GPS fix (3D=3) also does not by itself prove RTK
or establish which compass the EKF is actually using.

## Fix

- Read QGroundControl 5.0.7 `Vehicle::parameterManager()` cached
  `Fact::rawValue()` for `EK3_SRC1_YAW`, `COMPASS_USE`, and all
  available `COMPASS_DEV_ID/DEV_ID2/DEV_ID3` plus
  `COMPASS_PRIO1_ID/PRIO2_ID/PRIO3_ID`.
- A positive device ID means *some* compass device ID was loaded;
  it **does not** prove it is the physical IST8310 on I2C1. A
  secondary/priority compass ID is accepted as positive evidence,
  instead of falsely requiring only `COMPASS_DEV_ID`.
- Distinguish asynchronous QGC parameter synchronization, a missing
  or uncached EKF parameter, an explicit zero ID and a positive ID.
  Label the displayed EK3 yaw as the **configured source set 1**;
  it is not a live EKF estimator-source trace.
- On opening the GNSS diagnostic / clicking `Verifică GPS`, request
  **read-only** parameter refreshes from QGC for *already known*
  parameters, if its initial download is complete. Throttle to one
  request batch per 15 seconds/vehicle. Never request parameters on
  every GPS packet, change configuration or send PARAM_SET.
- Existing `PARAM_VALUE` read handling remains as a fallback for
  spontaneous messages; periodic cache polling updates the display
  without network traffic if the values changed.
- No changes to UM982 yaw packet selection, 3s freshness, vehicle
  heading source policy, ArduPilot EKF, motor, radio, cuves, or failsafe.

## Important remaining limits

- `EK3_SRC1_YAW=3` means *GPS yaw with compass fallback configured*,
  while `=2` is GPS yaw only. It does not prove that source set 1
  is currently selected, that EKF is using a specific bus, or that
  an actual magnetic fallback event has occurred.
- The current `compassFallbackActive` also requires a specific
  `STATUSTEXT` event (`EKF3 IMU… yaw fallback active`). Such text
  may be absent or different between firmware versions. Failure
  to receive the text is **not** proof that the external compass
  does not function. This branch intentionally does not claim a
  compass fallback is active from a healthy MAG bit alone.
- Confirm the external physical sensor from ArduPilot sensor listing,
  detected device IDs, bus/wiring, calibration and live EKF logs.
  The UI alone cannot prove the IST8310 model.
- Readback may initially remain pending if QGC is still downloading
  parameters. If `EK3_SRC1_YAW` is truly absent, inspect the real
  H743 `.param` and the firmware rather than inventing a value.

## Automated acceptance

- Qt/C++ heading tests: device ID only on `COMPASS_DEV_ID2` cached
  without `PARAM_VALUE`, configured EKF source read, refresh-once
  / 15s throttling, changed cached Fact value, link loss,
  loading-not-ready, and missing names without invented status.
- Full Qt dashboard smoke at narrow G20 widths, existing GNSS
  rotation/source regression, Android ARM64 build on PR HEAD.
- **Bench only**: connect H743; open GNSS diagnostic after initial
  QGC param download; verify the loaded values match QGC's parameter
  editor. Compare whether `COMPASS_DEV_ID` or `COMPASS_PRIOx_ID`
  shows the same sensor as the actual GNSS accessory. No
  configuration write without separate physical review.

Sources used during implementation: QGC 5.0.7
`src/Vehicle/Vehicle.h`, `src/FactSystem/ParameterManager.h`,
`Fact.h`; ArduPilot Rover EKF Source Selection and GPS for Yaw docs.
