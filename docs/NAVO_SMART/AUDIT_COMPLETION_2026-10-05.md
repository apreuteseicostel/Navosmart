# NAVO SMART — audit completion, 5 October 2026

Compared with `NAVO_SMART_Audit_Complet_2026-10-04.md` and the updated
`NAVO_SMART_Reparatii_2026-10-04.pdf`. Historical findings below are classified
against PR #20, rather than reapplied to an older branch.

## Confirmed baseline

At `9f2739f`, Android #797, recorded replay #62, display #54 and
firmware/persistence #90 are successful. Installed x86_64 acceptance verifies
the original recording at EOF, a separate saved lake, exact saved/restored sample
counts, native map geometry, a visible 3D page and paused Area Scan resume.
This is emulator acceptance, not connected boat acceptance.

Manual review of #797 screenshots completed in this continuation:

- Sonar PRO: populated ecogram, 0–50 m scale, echo strip, depth and X visible.
- Native map: georeferenced coloured surface and recorded GPS track visible.
- 3D before and after restart: rendered geometry visible, but partly outside
  the viewport at the top. Successful geometry counts did not prove framing.

## Software changes in this continuation

| Finding | Change | Validation boundary |
|---|---|---|
| 3D camera looked away from the dataset from a fixed world position | Camera now orbits a pivot at the terrain/track bounds centre. Fit distance accounts for aspect ratio, field of view and vertical exaggeration; top/isometric/reset and resize refit the scene. | Bounds and aspect-ratio regressions pass. New APK screenshots still required. |
| DigitalAnchor existed without an engage control | Map status rail exposes an anchor control. Replay, lost link and active mission/baiting block engagement. Navigation, baiting and START release the anchor. Pilot mode changes and invalid GPS cancel corrections. Anchor retains GUIDED after drift recovery instead of switching itself to HOLD. | Logic tested with explicit simulated vehicle. Actual station keeping, mode response and drift thresholds require H743/G20/boat. |
| EnergyGuard was never called by departure flows | Persistent, opt-in reserve/consumption settings now gate navigation, baiting and START/Resume. Route distance includes approach, all selected corridors and return HOME. Enabled checks reject invalid battery/route or insufficient reserve. Editing calibration disables the check until reconfirmed. | 50 local controller regressions and 7 G20 scenarios pass. Default check is OFF; measured consumption and physical acceptance remain required. |

Do not use #797 as evidence for these new changes. Current-head Android and
visual checks must pass before those parts can be marked installed-validated.

## Audit items already repaired or superseded

| Item from 4 October | Current status |
|---|---|
| Broken Nano firmware / no firmware CI | Real AVR compilation, parser tests and Lua bridge tests present and CI green. Flash/UART hardware remains pending. |
| Hopper blocked by absent Nano | Two-second fallback implemented; H743 link, calibration and PWM guards retained. Close retry covered by tests. |
| Lake deletion false success | Atomic catalog persistence, failure propagation and rollback implemented/tested. |
| G20 input missing / long press only stored | H743 `RC_CHANNELS` producer, independent controller, opt-in actions, release/debounce/stale guards implemented. Physical events remain pending. |
| Replay writes into live lake or uses live GPS for fish | Replay isolation guards and dedicated replay lake implemented/tested. |
| No native map renderer | Native surface topology exported with Dataset origin and rendered by production Canvas; #797 installed and visual evidence inspected. |
| Startup-only Android smoke | Real installed recording/map/3D/save/restart/Area Scan acceptance now runs in x86_64 CI. |
| AUTO selection starts mission | Selection no longer starts AUTO; explicit START with mission/link/GPS/sonar gates remains required. |
| First-run Units dialog / recovered boat visual | Defaults and recovered boat UI are already present. |

## Remaining acceptance and implementation

| Work | What is still required |
|---|---|
| Current-head software | Android build/runtime acceptance and inspection of the new 3D framing and Settings layout; portrait, pick, orbit/zoom, map HD and lake/spot mutations on installed APK. |
| G20 and H743 | ARM64 installation, real control/channel values, RC stream freshness, command ACK delivery, mode changes and loss/reconnect tests. |
| Hoppers | Mechanical output/PWM calibration; left/right/both release/close cycles; Nano absent; H743 link interruption and recovered closing. ACK is command-level, never physical position feedback. |
| Mission/baiting/anchor | Real upload/start/reached events, HOLD/RTL, Resume, arrival/drift/speed gates, station keeping and repeated loaded cycles on the boat. |
| Energy | Measure percentage consumption per kilometre and reserve on the actual boat; validate return distance and battery telemetry. No measured values are claimed here. |
| Live sonar/GNSS/camera | UM982/Kogger GPS/acquisition-clock alignment, channel identity, CHART v1 device evidence, ED2 LAN/discovery, actual camera URL/codec/frame freshness/reconnect. |
| Native archive | Persisted surface remains a bounded snapshot, not a full offline tile archive. Implement/archive acceptance is still separate work. |
| Legacy helpers | Global legacy persistence, ActionSequence, SonarRecorder and old fullscreen/backend still need consumer/migration review. No raw KLF recording/export workflow is claimed. |
| Downward beam | Lateral mosaic and native isobaths remain disabled; do not invent side-scan geometry. |
| Diagnostic automation / PCB | AutoFix remains diagnostic-only. CAD/assembly/electrical and physical boat verification require the actual relevant inputs/hardware. |

PR #20 remains draft, without merge. A successful software workflow cannot
close any physical acceptance item above.
