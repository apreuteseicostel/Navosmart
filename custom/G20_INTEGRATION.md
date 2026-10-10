# G20 advanced integration

G20 Device Tool owns physical-control-to-RC-channel mapping, reverse and endpoints.
NAVO Settings > Avansat • integrare G20 is collapsed on each Settings page load.
The RC listener lives on the Dashboard, independently of the Settings component.

The photographed preset is HOME CH6, L2 CH7, CAMERA CH8, L1 CH11, STOP CH13,
R1 CH15 and R2 CH16. The preset maps these to RTL confirmation, headlight,
camera, left hopper, HOLD, right hopper and sonar. Channels 1–4 (sticks),
5 (G-S), 9–10 (B1/B2), 12 (PUMP) and 14 (X3) are not dispatched.
No unverified mode-switch or axis behavior is inferred.

Hardware actions default OFF. The monitor remains available without enabling
actions. Settings persist using the existing NavoG20 category.
H743 must supply MAVLink RC_CHANNELS from its autopilot system/component on
the G20 telemetry link. This patch does not configure RC input wiring, ArduPilot
RC options, servo outputs or stream rates.

Before enabling actions on the boat:
1. Confirm that each physical control changes the expected monitored channel.
2. Confirm its released/pressed values; NAVO currently uses released <=1600,
   pressed >=1800, with valid PWM 900–2100.
3. Check ArduPilot auxiliary assignments. Avoid two owners of the same actuator;
   set its NAVO channel to 0 if H743 handles that function directly.
4. Verify calibrated hopper outputs and the existing link/mission gates.
5. Test HOLD, RTL confirmation and each hopper with the actual hardware.

Buttons must be released after startup, invalid input, stale telemetry (1 s),
vehicle change or link/replay reset. Duplicate assigned channels are blocked.
Regular actions debounce for 120 ms; hoppers and RTL retain configurable
long-press thresholds. A held button dispatches only once until released.

Local validation: 7 input scenarios, 31 existing controller regressions,
QML syntax and QObject moc. Android build, installed UI and hardware acceptance
must be checked on the resulting commit; earlier APK results do not validate it.
