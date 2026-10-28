# NAVO SMART V3 — GNSS UM982 heading priority (UI-only)

**Status: DRAFT • source code added to PR #29 • APK build / QML runtime / H743 hardware not run.**

## Problem reproduced by user

On the G20 the large heading compass and the boat on the map turn when the H743 is rotated. Rotating or exchanging the two UM982 antennas does not cause a corresponding response. In the original NAVO QML both `NavoHeadingCompass` and `NavoMap` used `vehicle.heading.rawValue` (H743 / ArduPilot attitude/heading), not the GPS's independently reported dual-antenna baseline heading. This difference alone explains the UI symptom, **but cannot prove whether UM982 itself is configured or working.**

## New path in PR #29

`UM982 dual antennas -> H743 GPS driver -> MAVLink v2 GPS_RAW_INT.yaw (GPS1) / GPS2_RAW.yaw (GPS2) -> NavoGnssHeading C++ -> QML -> heading compass and every NavoMap instance`.

The GNSS source is accepted only if:
- It is reported by the connected H743 system ID and autopilot component.
- Position fix is at least 3D (`fix_type >= 3`), with at least 4 known satellites.
- MAVLink `yaw` is present in the GPS extension: **1–36000 centidegrees**, where **36000 = 0° (north)**. `0` means unsupported, and `65535` means unavailable. Do NOT substitute `cog` / course-over-ground, or a merely valid GPS position.
- A valid yaw update was received in the last **3 seconds** on a currently live MAVLink link. Incoming invalid GPS readings clear previous validity immediately.

Selection: **valid GPS1 yaw > valid GPS2 yaw > current H743 heading > unavailable**. GNSS identity is labelled *GPS1/GPS2*, not unconditionally UM982: MAVLink source ID alone does not prove hardware make/model.

`NavoDashboard.qml` and all four embedded `NavoMap` views use the exact same chosen heading; the small and expanded heading compasses use it too. The GPS diagnostic popup lists GNSS heading, H743 heading, source, freshness and fallback explanation. If GPS yaw becomes invalid/stale, the UI falls back automatically to H743. The motor, rudder, autopilot's EKF, navigation modes, mission heading and safety guards are **not changed**.

**Important:** changing the UI display source is not configuring ArduPilot to navigate with GPS yaw. That is a separate hardware/firmware step and must be validated on the bench before autonomous use.

## Bench checklist before flight/boat test (propeller removed / ESC disarmed)

1. Place **Master** and **Slave** UM982 antennas at least **30 cm** apart with an unobstructed sky view, rigidly mounted relative to the hull. Do not infer antenna alignment by swapping cables.
2. Confirm the UART serial port **actually used** on H743: the **SERIALx_PROTOCOL = 5** belongs to that port, not an arbitrary assumption that the connector called TX2/RX2 maps to the same SERIAL index. Verify power, common GND, TX/RX crossing and baud.
3. Confirm on ArduPilot Rover: `GPS1_TYPE=25` (UM982 *moving baseline* rather than single-antenna `24`); `AHRS_EKF_TYPE=3`, `EK3_ENABLE=1`; check `EK3_SRC1_YAW=2` for GPS yaw or `3` for GPS with compass fallback when supported. Avoid `GPS_AUTO_SWITCH=2` for moving baseline. **Do not change parameters blindly before verifying present configuration.**
4. Measure offsets from **Slave to Master** in metres in the vehicle frame; check `GPS1_MB_TYPE` and `GPS1_MB_OFS_X/Y/Z`. Incorrect sign/axis may show reversed or offset yaw.
5. Check ground station MAVLink inspector for **GPS_RAW_INT.yaw** (message 24; MAVLink 2 extension) and any **GPS2_RAW.yaw** (message 124). Note whether yaw is 0 / 65535 or a valid 1–36000. If ArduPilot is not sending yaw over MAVLink 2, changing NAVO QML cannot fix the missing data.
6. Rotate the **whole boat/rigid antenna baseline** outdoors, watch source `GNSS GPS1` or `GNSS GPS2`; confirm heading changes while the boat stays stationary, independent of speed. Rotate H743 alone without moving fixed antennas: GNSS display should stay anchored; H743 backup may change. Then remove GNSS yaw deliberately to test fallback and recovery.
7. Read compass + boat icon in HARTA, MISIUNI, PUNCTE PESCUIT, 3D/other map host, Heading Up and diagnostic popup. Check reconnection, vehicle switch, poor fix, packet ageing >3 s. Do not enable AUTO/RTL based solely on the display.

## Acceptance tests to run only after user authorises CI

| Case | GPS fix | GPS yaw field | H743 heading | Expected UI |
|---|---:|---:|---:|---|
| Valid GNSS, stationary | 3+ | 9000 (90°) | 180° | GNSS GPS1, 90° |
| True North | 3+ | 36000 | 180° | GNSS GPS1, 0° |
| GPS valid, yaw absent | 3+ | 0 | 180° | H743 (rezervă), 180° |
| GNSS yaw temporarily unavailable | 3+ | 65535 | 180° | H743 (rezervă), 180° |
| Invalid fix | 2 | 9000 | 180° | H743 (rezervă), 180° |
| No fresh GPS message for 3 s | 3+ | stale | 180° | H743 (rezervă), 180° |
| No telemetry | -- | -- | stale | Indisponibil |
| GPS2 only | 3+ | valid GPS2 | 180° | GNSS GPS2 |
| H743 rotates, GPS yaw remains fixed | 3+ | 9000 | changes | GNSS GPS1, 90° |

Reference: [ArduPilot Rover GPS for Yaw](https://ardupilot.org/rover/docs/common-gps-for-yaw.html); [MAVLink GPS_RAW_INT](https://mavlink.io/en/messages/common.html#GPS_RAW_INT).

**All commits use [skip ci] and the PR remains Draft. No APK build is triggered.**
