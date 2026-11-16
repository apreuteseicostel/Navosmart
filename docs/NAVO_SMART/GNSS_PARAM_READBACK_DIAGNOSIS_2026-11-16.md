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


## Update: H743 actual parameter export P1.params (16 Nov 2026)

User-provided `P1.params` confirms ArduPilot Rover **4.7.2**, not necessarily live sensor status. The export is **not uploaded to the repository**.

- `GPS1_TYPE=25`, `SERIAL3_PROTOCOL=5`, `GPS1_MB_TYPE=1`. GNSS moving-baseline is configured, but no valid yaw has been observed in the supplied NAVO screenshots. `GPS1_MB_OFS_X=0.60`, `GPS1_MB_OFS_Y=0`, `GPS1_MB_OFS_Z=0`: the reference geometry is **Slave to Master** in body frame. Compare with physical antenna baseline previously reported around 0.33 m (possibly changed). Do not autoapply.
- `EK3_SRC1_YAW=3` (GPS yaw with compass fallback), `EK3_SRC2_YAW=1` (compass for separately selectable source set 2).
- `COMPASS_DEV_ID=0`, **`COMPASS_DEV_ID2=658953`**, `COMPASS_USE=1`, `COMPASS_USE2=1`, `COMPASS_PRIO1_ID=658953`, `COMPASS_PRIO2_ID=658953`. Discovery slot 2 is the external IST8310, whereas primary compass priority refers to the same ID; a duplicate PRIO2 setting should be reviewed in Mission Planner, not silently overwritten. Never edit COMPASS_DEV_IDx IDs manually.
- Consequently, checking only `COMPASS_DEV_ID` is **incorrect** on this vessel. New code requests/reads both device slots, both usage bits, and priority ID; selects actual nonzero registered device. Tests reproduce exactly these parameter values.
- `BATT_MONITOR=4`, `BATT_CURR_PIN=11`, `BATT_VOLT_PIN=10`, `BATT_AMP_PERVLT=66.7`, `BATT2_MONITOR=0`, `BATT_CAPACITY=16000`. This confirms the internal current monitor is still configured, not the planned upstream external current sensor on CU2/ADC7.
- Battery safety needs dedicated bench review: `BATT_LOW_VOLT=0` and `BATT_LOW_MAH=0` disable low threshold triggers; `BATT_FS_LOW_ACT=0` and `BATT_FS_CRT_ACT=0` mean **warn-only actions**, not automatic RTL/HOLD. `BATT_CRT_VOLT=12` is set but the critical action remains 0. Do not change without checking the actual Li-ion pack/sensor and return-to-home safety.

ArduPilot references:
- GPS yaw geometry: https://ardupilot.org/rover/docs/common-gps-for-yaw.html
- Compass priority vs discovered slots: https://ardupilot.org/plane/docs/common-compass-setup-advanced.html
- Rover battery failsafes: https://ardupilot.org/rover/docs/rover-failsafes.html
