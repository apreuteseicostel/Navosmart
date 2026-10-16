# NAVO V3 onboard service — integration candidate, not commissioned hardware

This service replaces the Nano transport for lights and sensors, and runs hopper cycles on H743. It is **disabled by default**. No .param export or installed firmware version has been provided; no output assignment is approved by this change.

## Installation after bench review

Copy `scripts/navo_v3_service.lua` into `APM/scripts/`, and `modules/navo_v3_core.lua` plus `modules/navo_v3_config.lua` into `APM/scripts/modules/`. The installed ArduPilot build must expose the Lua bindings used by the adapter. Keep the V2 bridge removed/disabled for V3 operation. Configure scripting through the normal firmware procedure; this code never writes autopilot parameters.

Fill the configuration from the actual wiring and calibration. Only then change `enabled` to true. Nil sections do not enable their capability. Review **physical pad ownership**, including aliases between servo outputs and GPIO numbers; the script can detect duplicate logical numbers but cannot infer all board-specific aliases. Protect motor, rudder, radio and GPS assignments. Do not copy historical proposed pins blindly.

- Hoppers: two dedicated output numbers (1-based), open/closed PWM, hold 100–2000 ms. Each output must have `SERVOx_FUNCTION=135` (constant trim), `SERVOx_TRIM=closed`, and MIN/MAX containing both values. The script refuses mismatches. Configuration is read at startup and before releases, not written remotely.
- Lights: two reviewed digital GPIO outputs, active high into the V3 MOSFET inputs. No PWM brightness or electrical feedback is claimed.
- Temperature: actual ADC pin, divider topology, series resistance, measured reference, nominal NTC resistance and beta. The test uses a synthetic 10k/10k divider; **it is not a statement of Rev F divider values**. Rails/out-of-range are invalid.
- Water: actual ADC, excitation GPIO, at least 100 ms settling, measured valid range and wet threshold/polarity. Calibrate dry, wet, open and short on the assembled Rev F circuit; arbitrary thresholds must not be enabled.
- RGB: reviewed serialLED output, one pixel, RGB/GRB order. Verify WS2811 timing, logic levels and channel order with the real module. Magenta means unavailable/fault, red wet/critical temperature, blue hopper cycle, green normal observed values. No buzzer/physical ACK is added.

## Hopper timing and its limits

MAVLink 31001 action 3 starts one onboard cycle. The core schedules explicit closure, even if Android disconnects. Opening uses `set_output_pwm_chan_timeout`, with constant-trim servo function as fallback. A duplicate request does not restart or extend the cycle. The servo override is loop-count based, **not an independent hardware watchdog**. Constant-trim refresh and scheduler timing can add latency after a script failure; verify the installed firmware's fallback under a stopped script on the bench. No closure guarantee is possible with lost servo power, mechanical blockage or failed autopilot.

The app no longer starts its close timer in V3. Its 5 s watchdog reports missing confirmation and does not claim physical closure. State returned by Lua is commanded state, not a limit-switch measurement. Phone and service must agree on both output numbers, all PWM values and hold duration before release. V2 retains its legacy behavior.

## Protocol v1

NAMED_VALUE_FLOAT, autopilot component 1, every 500 ms: `NV3VER=1`; `NV3CAP` bit mask (1 lights, 2 temperature, 4 water, 8 hoppers, 16 RGB); `NV3TEMP`, `NV3WATER`, `NV3WFAULT`, `NV3HEAD`, `NV3POS`, `NV3HOP` (mask 0–3), `NV3REQ` (last accepted request). App expires fields independently after 2.5 s. Version means service protocol, not physical PCB detection.

COMMAND_LONG 31001, addressed to exact vehicle/component 1 and accepted only from the configured GCS system/component (defaults 255/190; verify QGC settings):

| Parameter | Meaning |
|---|---|
| 1 | 1 far, 2 positions, 3 release hoppers, 4 close both |
| 2 | Lights: explicit 0/1; release: mask 1/2/3; close: 0 |
| 3 | Increasing request number 1–16777215, persisted by app |
| 4 | Release calibration: left output + 32 × right output |
| 5 | left closed PWM + 4096 × left open PWM |
| 6 | right closed PWM + 4096 × right open PWM |
| 7 | hold duration in milliseconds |

The packed integers fit exactly in float32 at supported PWM values. Action 3 checks the calibration payload; lights/close ignore it. Unsupported capability, malformed command or wrong calibration cannot actuate. ACK accepted means command accepted, not physical completion. Idempotency is per service boot; power-cycle/restart scenarios require bench acceptance. Sequence exhaustion is refused, never wrapped silently.

Thermal interlock: if a temperature input is configured, invalid or >=55 °C temperature forces far off and refuses far-on. With no temperature input configured this protection is unavailable. Battery undervoltage, autonomous water/thermal RTL/HOLD policy, G20 direct onboard actions and detailed latched RGB alarm patterns remain separate acceptance work. The current app safety policy remains active; this service does not silently choose navigation modes.

## Verification

`lua5.3 tests/firmware/v3-service.lua` executes the actual core and service using explicit I/O/transport fixtures: loss of app traffic, duplicate/stale requests, wrong sender/target, calibration mismatch, NTC conversion/rails, water settling, RGB and runtime failure. These fixtures do not simulate the actual ArduPilot output scheduler, ADC electronics or mechanics. C++ parser and QML tests cover the app integration; hardware/SITL/APK acceptance remains open.

API references inspected during implementation (master source; installed version must be checked):
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_Scripting/generator/description/bindings.desc
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_Scripting/examples/analog_input_and_GPIO.lua
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/SRV_Channel/SRV_Channels.cpp
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/SRV_Channel/SRV_Channel_aux.cpp
