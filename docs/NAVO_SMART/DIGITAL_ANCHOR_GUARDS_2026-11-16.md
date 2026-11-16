# NAVO SMART — Digital Anchor guardrails (16 Nov 2026)

## Scope and actual behavior

The existing `custom/qml/NavoDigitalAnchor.qml` is an **experimental**
app-side GUIDED target-reissue controller. It is **not** ArduPilot Rover LOITER,
not RTK station keeping, and not an onboard failsafe. The app must stay
connected for any subsequent corrections. Do not represent a GUIDED command
as confirmed boat positioning.

This change hardens the existing controller without changing any H743
parameter, motor output, arming state, RC mapping, hopper or failsafe.

## New constraints

- Engage only from confirmed **HOLD** or **GUIDED** flight modes; refuse
  **MANUAL, ACRO, AUTO, RTL or unknown**. An already active anchor cannot
  silently be retargeted.
- If the pilot changes to a different mode, stop correction immediately.
  Allow only a bounded 3-second transition from HOLD to GUIDED after engage.
- Require a live MAVLink connection, valid coordinates and GPS fix >=3.
  Unknown/stale GPS age cannot be independently verified by this QML
  controller: it is **not** an RTCM/RTK freshness gate.
- Reject NaN/negative computed drift and refuse correction after a sudden
  >15-metre distance from the saved coordinate (possible GPS jump).
- Apply 60% radius hysteresis (1.5 m engage radius, 0.9 m rearm radius)
  and at least 5 seconds between **reissued correction commands**.
- Display requests as *unconfirmed*, never report physical station-keeping
  success without hardware feedback.

The 1.5 m radius and 15 m jump threshold are provisional software
guardrails, not proven GNSS accuracy. Must tune from actual GNSS stability
and boat response.

## Acceptance and hardware prerequisites

1. Run `node tests/audit-regressions.mjs` (new cases for MANUAL/AUTO/RTL,
   takeover, rate limit, hysteresis, GNSS jump, invalid drift).
2. Verify NAVO core / Android PR builds for the exact commit.
3. On bench with propulsion physically safe/disarmed: test HOLD->GUIDED,
   immediate RC MODE CH5 manual takeover, GNSS loss/recovery, link loss,
   arming inhibition and re-entry. Review MAVLink mode/command logs.
4. On water with rescue/RC ready, test waypoint reissue and wind drift
   before claiming a digital anchor. Check that H743 remains the authority
   if Android closes.
5. Separately evaluate native ArduPilot Rover LOITER and its firmware/
   steering suitability. Do not silently swap GUIDED for LOITER.

## Related outstanding PRs

- #109 / #113: UM982 yaw and verified IST8310/EKF3 fallback (draft).
- #112: measured 4S battery voltage top pill (draft).
- #110 / #111: H743 current path and AirS water input migration (draft).
- #90–#101: experimental Kogger B/C/PRO branches; do not merge without
  comparing code/CI/G20 render performance.

The hardware and Android status remain **unverified** until tested on the
exact PR head. The change is intentionally kept separate from overlapping
dashboard, GNSS, battery and sonar PRs.
