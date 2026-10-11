# Saved fishing point actions — 11 October 2026

Tap a saved fishing marker or its label to open its details.
Holding it for about 600 ms and double click remain supported. The map input layer hit-tests the actual marker
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
dot/label taps, long press, responsive details/actions, disabled operations and removed-point
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

Android #839 compiled both APKs and passed recording, map/3D and restart/Resume,
but timed out in the first saved-point long press. Its input coordinates could be
reported before the viewport was focused and the marker transform polished. The
next change publishes coordinates only after map readiness, one-time focus and a
render-settling interval; ADB waits for that readiness and logs the actual physical
point. Local driver regressions reject pre-focus coordinates. The marker test now
uses touch events over a QGC-style touch area. The expanded Android phase still
requires its new run; the timeout is not considered closed by local tests alone.

## Ordinary tap correction

Android #840 passed on `805ec1dd`, including the installed saved-point long press,
all three action drafts and disconnected START refusal. The readiness correction
closed the #839 timeout. Kogger #104 and firmware/persistence #142 also passed.

Ordinary taps previously only selected the marker; the top map input layer did
not forward them to its details dialog. Both handlers now open existing-point
details for a tap on the dot or label. Tapping empty map space opens no dialog.
Real Qt touch checks pass at 236/320/900 px with the production input layer.
The Android installed phase now uses taps for navigation and scan, and retains
a long press for bait; the new APK workflow must complete before installed tap
acceptance can be claimed. Existing APKs need updating to receive this fix.

## Compact details card

The saved-point popup is now a non-modal, undimmed card at the bottom right:
maximum width 320 px and default height 250 px, capped at 48% of viewport height.
It exposes saved depth/temperature and boat distance immediately, with small
navigation, hopper/bait and scan-size/scan rows. Dark rounded controls and cyan
accents replace the large standard dialog. The visible X, Escape and outside
press close it; the map remains usable.

GPS, saved time and notes are under Details; the expanded card stays capped at
48% height and scrolls when necessary. Edit/List shortcuts and guarded mission
preparation remain intact. Real Qt touch/layout checks pass at 236/320/900 px,
including collapsed/expanded sizing, outside-close and the X. Installed Android
action lookup uses the buttons' explicit accessible names. The new workflow
must verify the final APK before installed acceptance is claimed.
