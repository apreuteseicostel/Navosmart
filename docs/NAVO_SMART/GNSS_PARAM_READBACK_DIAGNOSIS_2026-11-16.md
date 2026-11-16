# NAVO SMART — GNSS/IST8310 diagnostic readback fix (16 Nov 2026)

Status: **Draft software-only PR stacked on heading source priority PR #109. Not merged or hardware validated.**

## Operator evidence

NAVO diagnostics photos taken 16 Nov 2026 show 25–26 GPS satellites, MAVLink GPS fix 3, HDOP 0.80, **no valid dual-GNSS yaw**, `H743 / EKF (estimare) 54.00°`, SYS_STATUS magnetometer **HEALTHY**, but `EKF3 yaw source: Parametru necitit` and `Busolă fără ID verificat`. Separately, a Mission Planner `COMPASS_DEV_ID=658953` photo and a compass configuration screen explicitly identified external IST8310 (I2C1) enabled as `Use Compass` priority 2.

A healthy magnetometer and 54° from H743 do **not** establish that the live 54° is from IST8310. GPS 3D fix does **not** establish moving-baseline yaw. The actual `EK3_SRC1_YAW` and `COMPASS_USE` values are still **unknown** until received from the boat.

## Confirmed code problem

`NavoGnssHeading.cc` used only incoming MAVLink `PARAM_VALUE` messages. Those parameters are not broadcast on each heartbeat; when NAVO starts after the QGC manager loaded them, `COMPASS_DEV_ID`, `COMPASS_USE`, and `EK3_SRC1_YAW` remained "unread".

## Fix

- Read already-downloaded, typed `Fact` values from QGC v5.0.7 `ParameterManager` using `parameterExists` before `getParameter` (avoids spurious missing-param alerts).
- Automatically request the **three missing parameters** read-only using `ParameterManager::refreshParameter`, bounded to three attempts at 5-s intervals per vehicle link. The GNSS diagnostic opening / "Verifică GPS" button explicitly triggers a read-only refresh, rate-limited at 2 s.
- Expose and show numeric `COMPASS_DEV_ID` so **unknown, zero (absent), and nonzero (present/configured)** are not conflated. No device model is inferred from ID alone.
- Still select actual heading **only** from fresh GPS yaw, a confirmed EKF3 magnetic-fallback event with the expected configuration and health, or time-limited gyro/EKF bridge after a prior verified absolute yaw. No invented magnetic source or reinterpretation of 54°.
- Reset all magnetic/param data on vehicle/link changes. Never write `.param`, command motors or actuators, or change EKF navigation.

## Verification

Unit regressions in `tests/heading` exercise the operator's exact failure shape: magnetometer HEALTHY, H743 54°, yaw GNSS absent, three unread parameters, then an explicit request, a QGC parameter-cache hit on `COMPASS_DEV_ID=658953`, `COMPASS_USE=1`, `EK3_SRC1_YAW=3`, and the requirement of an actual EKF3 transition before marking a magnetic source active. Also test ID zero and source not fabricated.

CI: `tests/heading` Qt6 job included by `.github/workflows/navo-core.yml` in PR #109 ancestry. Must confirm status for the **new exact commit**. Android workflow only triggers on PRs targeting `main`, so this stacked PR may need a separate Android build after integration.

## Operator acceptance, with propulsion disarmed

1. Open NAVO GNSS diagnostic, then press "Verifică GPS". Confirm `ID busolă H743` becomes `658953`, and `EKF3 yaw source` becomes the actual value. It may be 1, 2, 3, or another value; do not assert 3 without readback.
2. Compare `EK3_SRC1_YAW`, `COMPASS_USE`, `COMPASS_DEV_ID` with Mission Planner and record exact output.
3. Outdoors, inspect raw `GPS_RAW_INT.yaw` and `GPS2_RAW.yaw` over MAVLink 2; `0` and `65535` are invalid; a good GPS fix alone proves nothing about yaw. Check UM982 dual-antenna output, antenna geometry and `GPS1_TYPE=25` if GNSS yaw remains unavailable.
4. Do not treat observed H743 54° or magnetometer HEALTHY as proof of safe autonomous navigation, and do not activate modes or edit calibration until physical bench validation is complete.

Sources:
- https://software.ardupilot.org/copter/docs/common-ekf-sources.html
- https://review.ardupilot.org/sub/docs/common-gps-for-yaw.html
- https://github.com/mavlink/qgroundcontrol/blob/v5.0.7/src/FactSystem/ParameterManager.h
