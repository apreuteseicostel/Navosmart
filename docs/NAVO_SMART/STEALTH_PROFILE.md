# Stealth — common speed, lighting and sound profile

Settings -> General -> STEALTH. Explicit session activation only; never restored
on startup/reconnect. Speed preference persists (default 0.6 m/s, 0.2–1.5 m/s).
Requires live vehicle and no replay to activate. Software implementation, not
measured quietness or hardware commissioning.

## Speed

The profile caps NAVO automatic speed requests; it does not change RC throttle,
servo mapping, flight mode, arming, geofence or failsafe parameters. NAVO direct
GoTo, Area Scan and baiting require live connection, GPS and AUTO/GUIDED for a
profile speed request. Requests use QGC's existing ground-speed API
(APMFirmwarePlugin sends MAV_CMD_DO_CHANGE_SPEED, ground speed, absolute).
The UI says requested, not accepted/measured. ArduPilot remains the authority.

Baiting ramp speed requests are capped without changing the configured normal,
silent, final or release speed thresholds. A smaller approach speed or stop
remains smaller/zero. Profile does not issue speed changes in MANUAL, ACRO,
STEERING, HOLD, RTL or SmartRTL, nor for missions not started through NAVO.
On explicit deactivation during live NAVO AUTO/GUIDED, the configured current
normal/task target is requested again. Mode transitions and actual response
must be validated on the installed Rover firmware. This is not a hard physical
speed limiter; current, wind or H743 rejection can cause different actual speed.

## Lights — existing G20 / H743 relay configuration

The boat already operates the lights directly through **ArduPilot Relay**, without
NAVO Android or Lua: G20 L2 -> RC7_OPTION=28 -> Relay1 -> H743 S6/GPIO55
(headlight); G20 R2 -> RC16_OPTION=34 -> Relay2 -> S7/GPIO56
(position lights). SERVO6_FUNCTION=-1 and SERVO7_FUNCTION=-1. This
installation was reported working and must not be reconfigured to use
Lua GPIO writes on the same pins. CH5 remains the mode switch.

Stealth uses the native MAVLink `MAV_CMD_DO_SET_RELAY` (181), relay
instances **0** for headlight and **1** for positions, with explicit ON/OFF
values. On explicit activation or manual "Reapply", request positions ON
then headlight OFF, once. RC remains functional without the app; no automatic
re-assertion over physical button changes. Manual UI commands use ArduPilot's
relay toggle value (2). On disconnection/replay, neither Stealth nor the app
may send light commands.

No reliable relay state feedback is currently available in this integration:
transport acceptance is not light confirmation. The UI displays "requested,
unverified" instead of falsely showing "confirmed" or timing out because
NV3HEAD/NV3POS are absent. On deactivation the app does not attempt to
restore headlight state from an unknown snapshot. Automatic position-light control is **not** enabled from a restored old AUTO
preference: the default is physical RC, and AUTO requires an explicit selection
in the current session. This prevents movement from unexpectedly overriding R2.
The optional Android RC listener does not redispatch L2 or R2 (and does not
open SONAR from R2); native ArduPilot handles those physical buttons.

The V3 Lua config must keep `lights=nil` for this boat. The V3 service can
continue handling separately verified hoppers and sensors; SHT31 and
water modules are independent read-only telemetry. Never run two
hardware control authorities on the same GPIO outputs.

## Sounds

Routine NAVO sounds/voice are suppressed while their visual notices remain.
Critical link/GPS/battery/water/temperature alerts keep the existing queue,
priorities, expiry and cooldown. During Stealth a critical event requests at
least a tone, even when routine sound/voice preferences are OFF; app audio volume
has a 50% minimum in this session. System mute, missing audio resources/engine,
Android routing and hardware volume still need actual G20 acceptance. Existing
critical playback is not stopped by toggling Stealth. Replay still suppresses
automatic alerts. QGC announcements and onboard H743 warning systems are not muted.

## Tests and pending acceptance

Production Qt controller/panel: ordered light requests/telemetry/timeout, pilot
override, one-shot requests, speed/mode/GPS guards, invalid preference, repeated
activation, link loss/reconnect, replay and vehicle swap; layout 236–900px.
Production alert tests: routine suppressed, critical tone with normal sound OFF,
critical playback preserved on toggle, replay suppression. Existing settings,
alerts, environment and controller regressions remain required in CI.

Still required: Android build and G20 installed UI/audio, H743 command acceptance,
real light wiring/thermal protection, speed/ramp and pilot takeover, loss/reconnect,
RTL/failsafe and loaded boat trials. No merge or hardware activation is claimed.

## 13 November 2026 correction

The first version of PR #73 assumed lights needed a live NV3CAP bit 1.
The verified G20/Relay configuration makes that assumption incorrect.
Use the already commissioned native ArduPilot relay interface;
do **not** activate `cfg.lights` or issue MAVLink 31001 for Relay1/2.
Physical tests must confirm accepted commands, manual override and
Stealth order with the installed Rover firmware.

## 13 November 2026 — QGC MAVLink relay command ACK serialization

G20 bench screenshot exposed QGroundControl's "Waiting on previous response to
same command" popup when two MAV_CMD_DO_SET_RELAY (181) commands were issued
synchronously. In QGC v5.0.7, Vehicle rejects a duplicate in-flight MAV_CMD
until its COMMAND_ACK result or terminal failure; changing relay numbers does
not change the MAV_CMD ID. The physical positions light switched while the
headlight remained on, matching that failure mechanism.

Fix in PR #73: Stealth sends **Relay2 positions ON** only, waits for
`Vehicle.mavCommandResult` (target autopilot component 1, command 181,
`ackResult=0`, `failureCode=0`), then sends **Relay1 headlight OFF**. It
waits independently for the second terminal ACK. Failure/no-response never
triggers the second command and never claims success. A 12-second watchdog per
step stops the sequence without automatic retries; the user may explicitly
reapply after investigating the hardware link. QGC popups are suppressed only
for these Stealth requests; the panel shows their status and distinguishes
an accepted MAVLink command from actual bulb illumination. Disconnect,
deactivate and manual override cancel any pending second step.

G20 L2/CH7 and R2/CH16 remain direct ArduPilot RC/Relay hardware controls
without Lua ownership; no change to H743 parameters, relay pins or modes.
