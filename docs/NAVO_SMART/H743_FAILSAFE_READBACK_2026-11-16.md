# NAVO SMART — H743 onboard failsafe read-only audit
Date: 16 November 2026. Status: Draft software, **no hardware commissioning**.

## Why

NAVO's application-side `NavoFailsafeController.qml` can request HOLD only
while MAVLink is connected. The app cannot dependably deliver an RTL/HOLD when
the transport has already failed. Radio/G20/GR01 and ground station (GCS)
heartbeat failures are distinct ArduPilot Rover triggers. The autopilot must
own motor/navigation failsafe behavior and recovery.

The 16 Nov exported real H743 `P1.params` (not committed) showed:
- `BATT_MONITOR=4`; `BATT_LOW_VOLT=0`, `BATT_LOW_MAH=0`,
  `BATT_FS_LOW_ACT=0`;
- `BATT_CRT_VOLT=12`, `BATT_FS_CRT_ACT=0`;
- `BATT_CURR_PIN=11`, `BATT_VOLT_PIN=10`, `BATT_AMP_PERVLT=66.7`.
This does **not** establish automatically actionable low- or critical-battery
failsafe. It also does not establish total 4S load measurement.

## Implementation

`NavoFailsafePanel.qml` reads **cached QGC Fact values, without writes**
from the active H743 through QGroundControl `FactPanelController`, only if:
1. the application link is available,
2. the FactPanelController vehicle is the **same object** as NAVO vehicle,
3. QGC's parameter manager is ready and contains the expected parameter,
4. the raw numeric value is finite.

If not, the line says `NECITIT`. A connection change resets all statuses
rather than showing old values. Only read-only parameter facts are used;
this does not force a full vehicle parameter refresh and is not a parameter
snapshot with independent freshness proof.

Panel lines:
- **Baterie LOW:** `BATT_MONITOR`, `BATT_LOW_VOLT`, `BATT_LOW_MAH`,
  `BATT_FS_LOW_ACT`.
- **Baterie CRIT:** `BATT_MONITOR`, `BATT_CRT_VOLT`, `BATT_CRT_MAH`,
  `BATT_FS_CRT_ACT`.
- **RC / GR01:** `FS_THR_ENABLE` and shared `FS_ACTION`.
- **GCS / MAVLink:** `FS_GCS_ENABLE` and shared `FS_ACTION`.

States distinguish **NECITIT**, **DEZACTIVAT**, **DOAR AVERTIZARE /
FĂRĂ ACȚIUNE**, **PARAMETRI INVALIZI**, and **CONFIGURAT (netestat)**.
Value 2 on RC/GCS enable means continue mission in AUTO and is clearly
labeled `AUTO exceptat`. Action 1 is RTL, 2 Hold, 3/4 SmartRTL fallback,
5 Terminate, 6 Loiter or Hold in Rover. Even if configured, this is **not a
working safety guarantee**. `onboardSafetyVerified` is always false.

The panel's 30/60/120 second spinboxes continue to control the **app-only**
diagnostic/recovery controller, NOT `FS_TIMEOUT` or onboard parameters.
Misleading dashboard text implying MAVLink can command HOLD after it is lost
was corrected.

## Bench acceptance checklist — no autonomous parameter changes

1. Disarm / remove propeller, ensure accessible physical RC override and safe
   battery supply. Compare every visible field with **Mission Planner** or
   a new H743 export from this same session. Close/reopen NAVO, disconnect/
   reconnect and switch vehicle to verify `NECITIT` when data is missing.
2. Verify `FS_THR_ENABLE`, `FS_THR_VALUE`, `FS_ACTION`, `FS_TIMEOUT`,
   `FS_GCS_ENABLE`, any timeout variants, and `FS_OPTIONS`. GCS failsafe
   monitors MAVLink heartbeats and is not identical to the RC receiver path;
   a GCS never connected might not trigger GCS failsafe.
3. Independently test transmitter-off and GCS-heartbeat-loss *while the
   motor is disabled*. Record H743 STATUSTEXT, mode, failsafe flags, manual
   takeover and recovery. Never assume that loss of video or Android UI is
   identical to lost RC/MAVLink.
4. Verify H743's **full-pack** voltage and current using an external meter,
   with both propulsion and auxiliary loads measured. Cross-check draft
   PR #110/#111 for shunt coverage and AirS/CU2 wiring before calibrating.
5. Only **after** validating 4S Li-ion chemistry, load sag, return distance
   and safe voltage envelope, review `BATT_LOW_VOLT`,
   `BATT_CRT_VOLT`, `BATT_LOW_MAH`, `BATT_CRT_MAH` and actions with
   Mission Planner. Threshold 12 V in the previous export is not a
   recommended automatic return threshold.
6. Test a hypothetical low/critical voltage transition in bench/simulation
   and then outdoors with a recovery plan. Verify `HOME` and GNSS/heading
   validity and real RTL behavior before marking a failsafe approved.

No ArduPilot parameter, servo, relay or motor command was sent from the PR.
App warnings are informational and don't replace embedded protection.

## Automation/regression

`node tests/audit-regressions.mjs` includes checks for the precise 16 Nov
voltage state, missing and stale QGC facts, offline switch, RC/GCS differences
and the correction of the dashboard's misleading HOLD guarantee.

CI / Android must pass on the **exact** PR head SHA. Keep this PR Draft
until simulation, propeller-safe bench and water acceptance.

## References
- https://ardupilot.org/rover/docs/parameters-Rover-stable-V4.7.2.html
- https://ardupilot.org/rover/docs/rover-failsafes.html
- https://github.com/mavlink/qgroundcontrol/blob/v5.0.7/src/FactSystem/FactControls/FactPanelController.h
- Related NAVO draft PRs #110/#111/#112 (battery) and #109/#113 (GNSS).
