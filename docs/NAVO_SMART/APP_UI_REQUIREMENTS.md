# NAVO SMART — UI requirements

## Dashboard
Romanian UI. Top status order: satellites -> Home -> speed -> battery -> temperature -> mode. Battery temperature is small/digital beside battery, not a separate card. Water alert, lights/headlight, hopper state, rudder/speed and LAN/SONAR/CAMERA state are visible. Camera front PiP belongs on dashboard.

Five top buttons stay compact. OFF/OFFL is preferred over long Offline wording. Autopilot icon must be visually clear.

## Boat and compass
Own boat marker replaces the QGC purple Q marker. Operator/G20 position is a separate remote-control marker when device GPS exists. Boat position comes from H743/UM982 and may differ from operator position. Home remains separate.

Small boat/compass: recognizable bait boat, sharper/longer bow, NAVO SMART on body, heading degrees, no cardinal letters. Large compass: N/NE/E/SE/S/SW/W/NW, 0–360 degrees and route deviation; cardinal marks semi-transparent.

## Map
Large map, zoom/reset, breadcrumb/trail, Home line, waypoint card with distance, confirmation for Navighează aici. MAP/HD/RUL/MAX controls vertically at right; controls about 50% transparent. Home near top controls; compass over map. Long-press can save a point.

## Responsive UI
Compact SVG icons, tooltip/hover text, avoid large text buttons where icons suffice. Right-side vertical controls. Scrollbar when content overflows. Layout must work on G20/phone as well as tablet/desktop.

## Sonar fullscreen
Max-width echogram extending to bottom. Narrow Putere ecou column at far right for full height. Compact icon toolbar/sliders; longer sliders; Day/NAVO theme must visibly change display. X close control must remain visible and correctly positioned.

## Camera fullscreen
Front camera naming. Fullscreen must always have visible X close control. Play/Stop and Cam OFF states are actionable.

## Ethernet settings
Two equal columns on wide screens. Host/IP field wide enough. Connect uses compact icon; Save before Units; camera controls aligned. Units section moved down/right when space permits.

## My Lakes
NAVO-style popup: narrower list left, spacious details right; HARTĂ/3D/PIN/SCAN compact icons with tooltips; compact add/edit/delete; dark controls; scrollbar; visible Nume baltă/lac input with adequate contrast.

## Fishing spots / baiting UI
Navigation/edit/bait/delete use compact aligned icons. Baiting: Alege punct and Setări on one row; Start/Stop/Nădire symmetric and spaced for touch. Settings are persistent and hidden until requested, not reopened every time.
