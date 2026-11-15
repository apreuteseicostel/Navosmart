-- NAVO physical RGB LED: WS2811, 5V, 3 wires (GND/+5V/DATA).
-- H743-Wing V3 dedicated LED pad is proposed as SERVO13, verify actual
-- DATA wire before setting SERVO13_FUNCTION=94 (Scripting1) manually.
-- RGB service is enabled by default but REFUSES to drive any other function.
-- Do not enable RGB in navo_v3_config.lua simultaneously (one LED owner).
return {
 enabled=true,
 output=13,
 required_servo_function=94,
 count=1,
 order="GRB", -- change to RGB only after testing the physical colour order
 update_ms=250,
 temp_alarm_c=45, -- matches NAVO app default alert; separate SHT31 input
 source_expiry_ms=3500,
 hopper_outputs={9,10}, -- read-only; accepts only SERVOx_FUNCTION=135
 hopper_open_pwm=1900,
 hopper_tolerance_us=100,
 -- brightness-capped to avoid driving the 3W LED continuously at full power
 brightness=0.30,
}
