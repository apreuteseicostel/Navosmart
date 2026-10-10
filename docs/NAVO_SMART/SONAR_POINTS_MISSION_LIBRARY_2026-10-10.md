# Sonar points and named missions — 10 October 2026

## Use

Select an active lake, open Sonar PRO, then Menu > Salvează punct din ecogramă.
The display pauses. Tap a visible CHART column, give the point a name/note and
save it, or choose SALVEAZĂ ȘI PREGĂTEȘTE MISIUNEA. The latter opens Mergi la
punct with a navigation-only destination. Select hopper actions, check the
speed/final behavior and use the existing confirmed START separately.

Mergi la punct and Traseu cu opriri expose MISIUNI SALVATE. Save a uniquely
named configuration, load it as a draft, or delete it with confirmation.
The library retains up to 25 configurations per lake, each with up to 50
stops, hopper actions and the final RTL/ANCHOR/HOLD action. The current boat
speed/approach profile remains in effect and is not included in the preset.
Point and route draft separation, existing load checks and energy gates remain.
Area Scan retains its existing per-lake saved geometry/resume flow; named scan
presets are not part of this change.

## Data and safety

Each displayed live column now copies GPS latitude/longitude, local receipt
time, water temperature and active lake identity at insertion. Processed bottom
updates still match the decoder sequence. Selection freezes the column metadata;
it never substitutes the boat's later position. There is no inferred horizontal
fish/object position: the point is the boat location associated with that column.
Unknown GPS, link loss or mismatched lake blocks point saving. The selected point
stores compact source evidence (sequence, observation time and scale), not a
second copy of the raw archive. Missing bottom/temperature stays unknown.

Replay points are blocked to preserve separation from the active live lake.
This stage does not enable annotation of archived replay sessions. Switching
lake or replay mode clears the selection/history and restores the previous
pause state. Closing the dialog also restores that state.

Point saving checks the existing atomic lake checkpoint and rolls back the
in-memory point on failure. Library save/delete/load also check persistence and
restore the prior state on failure. Old snapshots with no library remain valid;
invalid presets are filtered and lake reset clears the library. A loaded preset
never restores running state, load confirmation or dispatches vehicle commands.

## Validation

- Production JS/QML functions: original 51 controller scenarios and 19 route,
  library and sonar-point scenarios, including metadata retention, GPS/replay/lake
  guards, no START during preparation, restart and failed writes.
- Real Qt 6.8.3 Sonar PRO point dialog and mission-library dialog at 320/480/900 px.
- Existing real Qt Missions layout, route sequencing and resource module import.
- Android build/emulator verification runs on the final PR head. Hardware GPS
  timing/accuracy, live Kogger, G20 and physical bait delivery remain unvalidated.

Other proposed work (full offline base-map packages, session journal, voice
alerts and validated fish-presence alerts) remains for subsequent stages.
