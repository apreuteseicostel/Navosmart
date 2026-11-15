-- NAVO physical RGB LED: WS2811, 5V, 3 wires (GND/+5V/DATA).
-- H743-Wing V3 pad marked LED is physical PWM13 / SERVO13.
-- User confirmed the WS2811 DATA wire is attached to that LED pad.
-- Configure SERVO13_FUNCTION=94 (ScriptOut1) in ArduPilot parameters.
-- RGB service is enabled by default but REFUSES to drive any other function.
-- Do not enable RGB in navo_v3_config.lua simultaneously (one LED owner).
return {
 enabled=true,
 output=13,
 required_servo_function=94,
 count=1,
 order="RGB", -- S26/H743 bench: cyan appeared magenta with GRB (R/G swapped)
 update_ms=250,
 temp_alarm_c=45, -- matches NAVO app default alert; separate SHT31 input
 source_expiry_ms=12000, -- SHT31 sample cadence is 5 seconds; expire on stale streams
 hopper_expiry_ms=1750, -- reject stale commanded onboard hopper movement
 hopper_outputs={9,10}, -- read-only, accepted FUNCTION 0 or 135 on these dedicated channels
 hopper_servo_functions={[0]=true,[135]=true},
 -- G20 fallback when firmware lacks per-channel output PWM scripting readback.
 -- These RC channels trigger only a visual BLUE pulse, NEVER a servo command.
 hopper_rc_channels={11,15},
 hopper_rc_high_us=1800,
 hopper_rc_hold_ms=1400,
 hopper_blue_hold_ms=1600,
 hopper_open_pwm=1900,
 hopper_tolerance_us=100,
 -- brightness-capped to avoid driving the 3W LED continuously at full power
 brightness=0.30,
}
