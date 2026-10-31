# SHT31-DIS — interior temperature and humidity

Read-only monitoring, separate from battery NTC and water-in-hull detection.
Not hardware commissioned. SHT31 replaces the proposed DHT11 for NAVO V3;
DHT11/DHT22 remain usable on a separate ESP32 but are not handled by this driver.

## Firmware and installation

Required: ArduPilot Lua with `i2c:get_device()` and device `transfer(string, length)`.
The latter is present in upstream master inspected for this change, but absent in
the inspected Rover-4.6 branch. Do not assume the installed H743 firmware supports
it. The adapter reports NV3ENV=4 if the API/configuration is unsupported, and never
falls back to a register read or a timing-sensitive GPIO DHT reader. No firmware
upgrade or hardware configuration is performed by the Android app.

Copy `ardupilot/modules/navo_sht31.lua` to `APM/scripts/modules/`, and
`ardupilot/scripts/navo_sht31_service.lua` to `APM/scripts/`. Use the existing
reviewed V3 configuration module. New defaults:

```lua
interior_sht31={enabled=false,bus=nil,address=0x44},
```

Before enabling: identify actual module voltage/logic, review H743 bus mapping
against the installed firmware and boat wiring, assign bus, confirm address
0x44/0x45 and one driver per sensor. Do not enable TEMPn_TYPE=SHT3x for the same
I2C address while the NAVO script owns it. The script has an independent enable
flag; it never arms, changes modes, configures GPIO, lights, servos or a fan.
Existing NV3VER heartbeat from the V3 service is required for Android to accept
the environment data; do not enable unreviewed outputs to obtain that heartbeat.

Connection concept only: compatible 3.3V breakout -> suitable supply, common GND,
SDA/SCL at H743-safe levels. No physical pins or bus number are assumed here.
Keep the sensor away from regulator heat, spray and pooled water, exposed to the
interior air. It is not a waterproof leak probe. No NAVO PCB modification required
if a suitable external I2C connection is available; this must be checked.

## Acquisition and telemetry

Independent script; 100 kHz I2C, one retry, single-shot 0x2400, read six bytes after
at least 20ms, then wait 5 seconds. Both two-byte measurements require Sensirion
CRC-8 polynomial 0x31, initial 0xff. No conversion wait in a busy loop, no heater.
Short/malformed reads, NACK or driver exceptions invalidate the current reading.
The 20ms callback is a scheduling request, not guaranteed timing.

| NAMED_VALUE_FLOAT | Meaning |
|---|---|
| NV3ITMP | Interior air temperature in degrees C |
| NV3HUM | Relative humidity, 0–100 %RH |
| NV3ENV | 1 waiting, 2 valid, 3 read/CRC/stale error, 4 unsupported API/config |

Measurements are published only on successful acquisition; status every second.
Android validates autopilot component/system identity, V3 heartbeat, status age
<2.5s, independent measurement ages <12s and finite values. Humidity outside
0–100 or temperature outside -40–125 is invalid. Non-live status clears old
measurements; status alone cannot revive them. Vehicle change resets the state.
Disabled/no telemetry is shown as unavailable, not 0% humidity.

## NAVO UI and alerts

Tap dashboard TEMP -> scroll below the battery-temperature graph -> INTERIOR COCĂ.
Shows actual temperature, relative humidity, reception age and explicit diagnosis.
Battery NTC graph and its critical alert remain unchanged. Environment values are
hidden during replay or loss of the vehicle link.

Environment warnings default OFF, with editable illustrative thresholds 80%RH and
45 degrees C. Settings persist under NavoEnvironment. Warnings use existing
opt-in audio/voice controls, edge detection/cooldown and replay suppression;
they are advisory, do not assert a leak or trigger RTL/arming/ventilation.
No historical humidity graph or persistent environment-event journal is claimed.

## Verification and outstanding commissioning

Tests: CRC vectors (including BE EF -> 92), exact length, conversion, timing,
read failure/recovery, disabled/unsupported API, actual service telemetry and
millis rollover. Qt C++ covers message sources, invalid ranges, sensor independence,
status/measurement expiry and reset. Production QML tests cover compact screens,
status text, opt-in alerts, unknown readings, deduplication and replay suppression.

Still required: installed firmware capability, actual module and bus, voltage,
sensor address/driver ownership, bench reads/disconnection/restart, comparison to
a reference, G20 display/audio and loaded-system behavior. CI is not physical
validation. The master QUEST DHT11 integration note is historical for this choice.

Protocol reference: Sensirion SHT3x-DIS datasheet (single-shot table, CRC and conversion).
API reference: ArduPilot libraries/AP_Scripting/docs/docs.lua and lua_bindings.cpp.
