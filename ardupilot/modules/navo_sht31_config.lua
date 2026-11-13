-- NAVO SHT31-only read-only service configuration.
-- Does not enable the NAVO V3 actuator service or configure any GPIO/servo.
-- Set enabled=true only after checking 3.3V I2C signal levels and wiring.
-- MatekH743 ArduPilot I2C bus 0 is physical CL2/DA2 (I2C2).
-- Disable TEMP1_TYPE for the same I2C device before enabling this script.
return {
    enabled=false,
    bus=0,
    address=0x44,
}
