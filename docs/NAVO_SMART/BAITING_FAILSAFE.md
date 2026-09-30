# Automatic baiting and failsafe

## Baiting
Automatic baiting supports Left / Right / Both hopper selection, target selection, confirmation, persistent settings, acceleration/deceleration ramp and touch-friendly Start/Stop/Bait controls.

Controller states: idle -> navigate -> approach -> final -> settle -> release -> exit -> RTL/complete, with aborted path. Nominal software values currently used: speeds 1.5 / 0.8 / 0.4 m/s; arrival radius 1 m; maximum release speed 0.12 m/s; settle 2 s; post-drop 2 s; exit distance 4 m; GPS grace 1.5 s. Link loss aborts. Target is rechecked after stopping/settling before hopper release.

Hopper actuation is H743/MAVLink, not Nano. Current bridge defaults to H743 outputs 9/10, closed 1500 us, open 1900 us, hold 900 ms; these are starting values only and require physical JX6221 calibration.

## Failsafe
H743/ArduPilot is authoritative if Android disappears. App-side current logic: link grace 30 s; GPS recovery window 60 s; GPS return-home threshold 120 s. GPS loss requests HOLD first; do not command position-dependent RTL while position is invalid. Exact ArduPilot failsafe parameters must be verified for the installed firmware before writing them to hardware.
