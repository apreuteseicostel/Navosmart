# NAVO SMART — Master project record

Recovered from project discussions through 30 Sep 2026. This file records durable decisions; topic files hold implementation detail.

## Product
DIY smart bait boat, hull about 80×30×20 cm, two bait hoppers. Android app name NAVO SMART; Romanian UI; header NAVO SMART; footer Pescarul lu Peste. Default vehicle is Boat/Navomodel; vehicle selector belongs in Settings, not startup.

## Core hardware
Matek H743-WING V3 + ArduPilot; Unicore UM982 dual antenna; Skydroid G20 + GR01; Arduino Nano on NAVO SMART V2 E1 auxiliary PCB; motor 4250 800kv; Flycolor 50A water-cooled ESC 2–6S; 4S Li-ion 16,000mAh, 16.8V max; JX6221 hopper servos ×2; rudder servo 4806. Planned Kogger Sonar Basic 2D Plus and waterproof Ethernet camera are physically deferred until the end.

## Authority
H743 owns propulsion, rudder, hopper servos, RC, AUTO/HOLD/RTL and missions. Nano monitors servo PWM and sensors and drives auxiliaries only. Nano failure must not remove critical boat control.

## Software priority
Stable installable APK -> bathymetry/HD/persistence/3D -> Area Scan end-to-end -> waypoints/lakes/baiting -> final UI -> real H743+UM982+Nano+GR01 -> physical Kogger/camera last.

## Validation rule
Software/build success is not hardware validation. Before wiring, exact H743/ArduPilot/UM982/GR01 parameters and voltage/pin assumptions are rechecked against official documentation and then tested on real hardware.
