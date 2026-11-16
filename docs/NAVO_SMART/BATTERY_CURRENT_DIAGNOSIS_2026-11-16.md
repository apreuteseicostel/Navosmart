# NAVO SMART — 4S battery current and 10 W headlight diagnosis (16 Nov 2026)

**Status: read-only UI diagnosis in Draft PR; no verified hardware calibration.** Never treat displayed `V × A` as whole-boat power until the monitored electrical path is verified.

## Observed problem and code finding

Operator reports pack voltage correct, NAVO battery detail reporting roughly 3 W, and no change when the physical G20 L2 / Relay1 10 W headlight is switched on. `NavoStatusDetails.qml` reads QGroundControl battery 0 (`battery.current.rawValue`, A) and voltage (V), then derives power as `voltage * current`. It does not measure current in the phone, nor does it apply the 10 W nominal lamp rating. At 16 V, 3 W corresponds to only 0.1875 A; the nominal 10 W headlight alone would draw about 0.625 A input *if* its driver input is 10 W. Converter efficiency and actual light rating can change the reading.

The project RevF power plan feeds ESC through the H743 power path, while 10 W headlight / J1 battery branch, external 12 V buck-boost, and external 5 V feed are separate. The physical current shunt only senses the branches that cross its actual battery-to-load path; common ground or shared voltage does not imply current sensing. The R1 interconnect plan specifically warns against bypassing the ESC shunt. **This is a likely explanation, not an as-built wiring audit.**

## On-bench verification (motor DISARMED, propeller disconnected)

1. Export full current ArduPilot `.param` before any changes. Record firmware/board revision and `BATT_MONITOR`, `BATT_VOLT_PIN`, `BATT_CURR_PIN`, `BATT_VOLT_MULT`, `BATT_AMP_PERVLT`, `BATT_AMP_OFFSET`, and any `BATT2_*`. Official ArduPilot Rover guidance for WING V2/V3: `BATT_MONITOR=4`, `BATT_VOLT_PIN=10`, `BATT_CURR_PIN=11`, `BATT_AMP_PERVLT=66.7` *nominal*, whereas 40 is generic for other variants. These are **checks, not a parameter file to import**; voltage already works, so avoid changing its multiplier without measurement.
2. Compare MAVLink Inspector or QGC battery current with NAVO at the same time. MAVLink `SYS_STATUS.current_battery` and `BATTERY_STATUS.current_battery` can be inspected; check their scaling and absent/sentinel values per MAVLink protocol. If telemetry already shows 0.19 A, the app's 3 W arithmetic is behaving as written; focus on sensor path and calibration.
3. Measure the *actual* current drawn by the entire boat using a DC-capable clamp meter of adequate sensitivity around **only one** main battery conductor **before any load branches**; or use a properly rated **inline DC wattmeter / shunt installed with power fully disconnected** by someone qualified to handle high-current Li-ion 4S wiring. An ordinary low-range multimeter should **not** be put in series with the 50 A ESC feed. Never clamp around positive and negative together.
4. With propulsion disabled, note external current and displayed current with **far OFF**. Switch far ON using physical G20 L2, wait 3–5 seconds for reports to settle, note both readings and compare `delta A` / `delta W` using the new passive NAVO battery test. The app buttons only capture snapshots, **do not command the lamp**. Repeat at least twice.
5. If the external meter rises by roughly 0.5–0.8 A (nominal lamp at 12–16.8 V with actual driver efficiencies) but H743 does not, the far bypasses its sensing path (or monitoring is configured incorrectly). Do **not** fake a 10 W addition in software, because ON could fail or lamp efficiency vary.
6. If the external meter and H743 both respond but disagree in scale, check the actual `BATT_AMP_PERVLT` and `BATT_AMP_OFFSET`. Calibrate against measured current at multiple loads following official ArduPilot calibration guidance; never compensate for an **unmeasured branch** by arbitrarily increasing the multiplier.
7. If all loads must appear as a **single total** pack current, place a suitably rated external current sensor **upstream of all power splits**, or redesign the power distribution around a correctly rated shunt. Matek advertises a high-precision current sensor but board current path has physical continuous/burst limits; do not reroute a 50 A ESC + peripherals through an unverified track or connector. Alternative external analog sensor can potentially feed WING V3 CU2 (0–3.3 V, monitor2 current pin 7); verify wiring, pin configuration, sensor type, and reporting separately. Do **not sum monitor1 and monitor2 if either overlaps**.

## Acceptance criteria

- Under fixed external load, QGC/ArduPilot current and NAVO current agree in amps (small update/rounding delay allowed).
- Adding/removing a lamp produces a corresponding nonzero *total-battery* current change in an upstream meter. The onboard H743 monitor may still be intentionally **partial** until rewiring or installing an upstream sensor.
- Monitor scale matches a calibrated meter at idle and at a safely applied second load; zero-current offset assessed.
- UI labels battery power as **through the monitor**, not measured whole-boat consumption, with clear uncertainty and operator-controlled capture; off/on snapshots reset on disconnect or vehicle change.
- No modification of ESC, Relay1/2, Lua, AUTO/RTL, H743 parameters or high-current wiring is done remotely.

References:
- https://ardupilot.org/rover/docs/common-matekh743-wing.html
- https://ardupilot.org/rover/docs/common-analog-current-calibration.html
- https://mavlink.io/en/messages/common.html#BATTERY_STATUS
- Project: `docs/NAVO_SMART/PCB_NAVO_SMART_V3_REVF.md`, `docs/hardware/2026-10-15/Schema_conexiuni_R1.md`.
