# NAVO SMART — Master project record

Recovered from project discussions through 30 Sep 2026; updated for the V3 hardware decision on 13 Nov 2026. Topic files hold implementation detail. Historical V2 design notes below are not active hardware requirements.

## Product
DIY smart bait boat, hull about 80×30×20 cm, two bait hoppers. Android app name NAVO SMART; Romanian UI; header NAVO SMART; footer Pescarul lu Peste. Default vehicle is Boat/Navomodel; vehicle selector belongs in Settings, not startup.

## Core hardware
Matek H743-WING V3 + ArduPilot; Unicore UM982 dual antenna; Skydroid G20 + GR01; **V3 RevF auxiliary PCB has no Arduino Nano or processor** (Nano belonged to historical V2 E1); motor 4250 800kv; Flycolor 50A water-cooled ESC 2–6S; 4S Li-ion 16,000mAh, 16.8V max; JX6221 hopper servos ×2; rudder servo 4806. Planned Kogger Sonar Basic 2D Plus and waterproof Ethernet camera are physically deferred until the end.

## Authority
V3: H743 owns propulsion, rudder, hopper servos, RC, AUTO/HOLD/RTL, missions and onboard V3 service logic. H743 uses ArduPilot/MAVLink telemetry and hardware-specific services for supported sensors and outputs, subject to pin mapping and bench validation. The V2 Nano monitor/bridge is retired and must not be required by V3.

## Software priority
Stable installable APK -> bathymetry/HD/persistence/3D -> Area Scan end-to-end -> waypoints/lakes/baiting -> final UI -> real H743+UM982+GR01 (without Nano) -> physical Kogger/camera last.

## Validation rule
Software/build success is not hardware validation. Before wiring, exact H743/ArduPilot/UM982/GR01 parameters and voltage/pin assumptions are rechecked against official documentation and then tested on real hardware.
