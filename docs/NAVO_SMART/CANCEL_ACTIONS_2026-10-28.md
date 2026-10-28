# NAVO SMART — Cancel actions and Area Scan explanations

Based on PR #29 head `3fed190ebd49935b8673dce93d99e26fb2600348`.

## Behaviour

- The mission strip stays available for active navigation, AUTO/GUIDED, pending mode commands and RTL, including RTL started outside the app. The red **ANULEAZĂ** button becomes **ANULEAZĂ RTL** during RTL. It remains usable after link loss to cancel local continuation, but reports that HOLD was not sent.
- Existing route/nădire STOP controls and Area Scan cancellation use the same handler. It cancels pending local START, route continuation and bait timers (including the leftover speed ramp after transition to RTL), pauses Area Scan for explicit Resume, invalidates upload verification, releases the app anchor, and requests HOLD once. An already requested hopper release is asked to close through the existing close path when connected. Released bait cannot be recovered; physical closure is not asserted.
- HOLD dispatch is distinct from the mode reported by H743. The usual mode timeout remains active. No automatic restart/retry, disarming, mission erasure on the vehicle, parameter changes or failsafe disabling is introduced. An autopilot failsafe can still override a requested mode.
- In-flight mission transfers may still finish in QGC/on H743. Cancel invalidates local verification; late completion cannot authorise a new START. New upload is subject to QGC's existing sync guard.
- **Șterge zona** is a separate confirmed action. It removes Area Scan geometry, lane progress and resume route; clears the outline/draft in all four map hosts; invalidates the prepared NAVO mission. It preserves sonar samples, track, bathymetry, surface mesh, fishing points and saved route libraries. It does not erase a stored vehicle mission. Active movement, pending mode commands, unpaused sonar scanning, replay and QGC sync block deletion. If the per-lake checkpoint fails, geometry and progress are restored.
- The Area Scan toolbar has permanent captions and hover/press explanations. Drawing tools have captions, hover and touch help. Left/right map controls show a help banner for four seconds after press in addition to their hover tooltips.

## Source changes

`custom/qml/NavoDashboard.qml`, `NavoMap.qml`, `NavoMissionStatus.qml`, `NavoScanCoordinator.qml`; `tests/audit-regressions.mjs`.

The existing GNSS regression incorrectly searched for `kYawTimeoutMs = 3000` in the `.cc` file. The assertion now reads the header where that constant is declared; heading logic is unchanged.

## Validation

- `node tests/audit-regressions.mjs`: 85 scenarios passed, including 13 new cancellation/deletion/help scenarios executing production QML JavaScript with explicit mocks.
- `node tests/route-plan.mjs`: 20 scenarios passed.
- `node tests/g20-input.mjs`: 7 scenarios passed.
- `node tests/steering-bottom.mjs`: 10 scenarios passed.
- Balanced QML delimiters in the four changed QML files; `git diff --check`: passed.
- No Qt/QML runtime, Android build, emulator, APK or hardware test was run. Commits use `[skip ci]`; keep the PR Draft and do not merge without user approval.

## Remaining device acceptance

On G20 with hardware commissioned, verify all buttons remain reachable in compact/fullscreen views, captions and help fit the display, RTL/HOLD confirmation and timeout are accurate, cancellation during approach/drop never dispatches another stop, and old Area Scan geometry stays cleared after saving/restarting while sonar data remain available. Check pilot takeover and autopilot failsafe behaviour independently. No device command has been sent by this source-edit task.
