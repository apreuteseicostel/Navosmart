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

## Lights

Fixed policy: positions ON, headlight OFF; RGB and H743 buzzer untouched.
Needs fresh V3 capabilities/state and an available command path. First request
positions ON, wait for reported state, then request headlight OFF. State is
confirmed only by fresh H743 telemetry; no electrical/optical feedback is claimed.
Five-second timeout; bounded requests, no repeated enforcement/flooding. Reapply
requires another explicit click after timeout/unavailable/pilot override/change.
Without the V3 light service, profile is clearly partial, not falsely confirmed.

Existing AUTO position-light switching is suspended during the profile. Manual
G20/app lighting commands have priority and mark the lighting portion overridden.
Profile never commands position lights OFF. Explicit profile deactivation can
request the previously ON headlight again, only on the same live session with
fresh service and no pilot override; H743's thermal guards still apply. Positions
remain ON on exit. Lost link/replay/vehicle change cancels the profile without
restoring lights or replaying requests after reconnect. No hardware mapping or
service commissioning is performed by activating this UI profile.

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
