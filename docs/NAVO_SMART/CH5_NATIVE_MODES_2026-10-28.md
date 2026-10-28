# CH5 controls the real H743 mode; MOD displays H743 confirmation

The physical G20 three-position switch must reach H743 as RC channel 5.
H743/ArduPilot Rover owns switching via MODE_CH and MODE1..MODE6. The
application never turns an RC_CHANNELS message into a second set_mode command.
This keeps pilot mode selection working when NAVO is closed or telemetry is lost.

## Deployable native profile

`ardupilot/params/navo_ch5_manual_auto_guided.param` configures:

| Input | Native slots | H743 mode |
|---|---|---|
| Low (e.g. 1000/1165 us) | MODE1, MODE2 | MANUAL (0) |
| Middle (e.g. 1425/1500 us) | MODE3, MODE4 | AUTO (10) |
| High (e.g. 1815/2000 us) | MODE5, MODE6 | GUIDED (15) |

MODE_CH=5 selects the actual RC input. RC5_OPTION=0 prevents an additional
auxiliary action on the same channel. No arming, servo, throttle or failsafe
parameters are included. MODE1..MODE6 are native Rover mode parameters, not an
app animation. This is the intended low-to-high PWM order; physical lever labels
and direction still require checking in the G20 channel monitor.

Source references:
- https://ardupilot.org/rover/docs/common-rc-transmitter-flight-mode-configuration.html
- https://ardupilot.org/rover/docs/parameters.html#mode-ch-mode-channel

## Applying on H743 (not executed by this source-edit task)

With the boat secured and propulsion isolated, save the current H743 parameter
backup. Confirm Rover/Boat firmware, valid RC reception and the actual CH5 PWM
in all three positions. Check CH5 is not also mapped to throttle/steering or an
onboard script. Import the profile with the GCS parameter loader, review the eight
changed parameters, save/reboot as required by the firmware, and read them back.
Verify the three positions against actual H743 mode telemetry with NAVO closed,
then with NAVO open. Native AUTO may start the stored mission if the vehicle is
already armed; this profile does not arm the vehicle. GUIDED selects the mode;
it does not invent a destination, start a scan or release a hopper.

The profile has NOT been installed or verified on the user's H743. An APK alone
cannot change an unconfigured receiver/mode-channel mapping. Hardware acceptance
and motor commissioning remain outstanding; no device command is sent here.

## App behavior

The small MOD card reads only the connected Vehicle.flightMode from H743.
It shows MANUAL/AUTO/GUIDED after telemetry confirms that mode; HOLD, RTL and
other reported modes remain visible as reported. Disconnection shows --.
Changing or losing CH5 telemetry cannot fabricate a confirmed mode. The card
has no click action and the old OFF/MANUAL/AUTO popup is removed. Battery and
temperature diagnostics are retained.

CH5 is reserved from NAVO's other RC button mappings. The obsolete modeSwitch
helper, unused mode3Action setting and fake AUTO status-only path are removed.
Native ArduPilot failsafes/rejection remain authoritative; NAVO does not retry
a mode to fight a failsafe. Existing app missions still use their explicit START
flow; native physical AUTO is a separate pilot request to the onboard firmware.
