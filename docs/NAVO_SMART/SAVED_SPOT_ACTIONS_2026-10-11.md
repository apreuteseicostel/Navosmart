# Saved fishing point actions — 11 October 2026

Hold a saved fishing marker or its label for about 600 ms to open its details.
Double click remains supported. The map input layer hit-tests the actual marker
bounds before offering a new point, so a long press on an existing label does not
create a duplicate at the pointer position.

Details include name, saved depth/temperature, GPS, saved time, note and current
boat distance when GPS is available. The responsive, scrollable dialog offers:

- Navigate: prepare a point mission with no hopper action.
- Bait: choose left, right or both, then prepare a point mission.
- Scan: generate a square centred at the saved coordinate, with a 10–100 m side
  (20 m initial setting). This prepares geometry; upload and START remain separate.
- Edit: open the existing fishing point editor; List opens the points page.

Navigation/baiting opens Missions and its stop editor. START still requires the
existing prelaunch/link/GPS/energy/save checks, confirmation and loaded-hopper
acknowledgement. New destinations clear that acknowledgement. These shortcuts
issue no navigation, mode, upload or servo commands by themselves.

The Dashboard resolves the point ID again in the current lake and uses current
stored coordinates. Missing/deleted points, invalid coordinates, replay, an active
mission/baiting/upload/start request or steering ownership block preparation.
The popup closes if its point disappears or the lake changes. Scan geometry near
the date line or above 85 degrees latitude is rejected; check that the square is
inside the lake before upload. The viewport and GPS do not guarantee physical
arrival accuracy, safe passage, a sonar reading or hopper movement.

Validation: actual QtLocation markers and the production map press handler pass
long press, responsive details/actions, disabled operations and removed-point
closure at 236/320/900 px. Production route/Dashboard JS verifies current-ID
resolution, navigation/hopper choices, centred scan corners, no START and blocked
operations. Existing route/Missions Qt checks and 51 audit regressions pass.
Android/G20 and physical boat acceptance remain separate. PR #20 stays draft.

## Installed acceptance extension

Android #838 completed successfully on commit `63844bf`; its existing installed
checks cover replay, native map/3D, persistence/restart and Area Scan resume.
The saved-point gestures/actions had only the local Qt/controller evidence above.

The next commit adds an explicit installed `spots` phase after record/restore:
real marker long press via ADB, screenshots of all three action dialogs, navigation
draft with no release, both-hopper bait draft with cleared load confirmation,
40 m scan geometry centred on the saved coordinate, and refusal of disconnected
START. Scene lookup distinguishes visible controls and converts marker position
from Qt logical coordinates to physical input pixels. ARM64 release builds keep
this acceptance helper disabled. Native helper compilation and the expanded
Android phase require their new workflows; they are not claimed passed locally.

Local validation includes the production acceptance state transitions with explicit
UI doubles, refusal to report success for an unsafe START, actual Qt stop replacement
clearing load acknowledgement, and the existing real Qt marker/map/Missions tests.
