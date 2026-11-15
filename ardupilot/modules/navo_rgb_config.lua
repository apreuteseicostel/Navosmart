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
 order="RGB", -- physical positions showed purple for requested cyan: test RGB instead of GRB
 update_ms=250,
 temp_alarm_c=45, -- matches NAVO app default alert; separate SHT31 input
 source_expiry_ms=12000, -- SHT31 sample cadence is 5 seconds; expire on stale streams
 hopper_expiry_ms=1750, -- reject stale commanded onboard hopper movement
 hopper_outputs={9,10}, -- verify against actual calibrated hopper outputs in NAVO settings
 -- A fallback only; V3 service remains disabled until calibrated and enabled.
 hopper_open_pwm=1900,
 hopper_tolerance_us=100,
 -- brightness-capped to avoid driving the 3W LED continuously at full power
 brightness=0.30,
}
