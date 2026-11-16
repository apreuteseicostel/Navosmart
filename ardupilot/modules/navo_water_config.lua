-- NAVO SMART V3 RevF: standalone read-only hull-water monitor.
-- Disabled until J12 continuity/wiring and H743 assignments are verified.
-- Original J12.3 -> CU2/ADC7. After verified rewiring, J12.3 -> AirS/ADC4.
-- AirS uses a built-in 1:1 divider. The ArduPilot SCALE(2) compensates the
-- voltage_latest reading, but actual water thresholds require recalibration.
-- Never copy example thresholds: measure dry/wet/open/short voltages on the actual board.
return {
    enabled = false,
    -- Keep ADC7 for existing installed scripts UNTIL the wire is actually moved.
    -- After removing J12.3 from CU2 and connecting it to AirS, set adc_pin=4.
    adc_pin = 7,          -- legacy: CU2 / PA7 / ADC7; new: AirS / PC4 / ADC4
    airs_wiring_verified = false, -- only set true after checking soldering, 0..3.3V input,
                                  -- ARSPD_TYPE unused and bench voltage/readback;
                                  -- NEVER means probe dry/wet is calibrated
    exc_gpio = 57,        -- J12.2 -> S8 / PD13 (if physically wired)
    settle_ms = 120,      -- pulsed excitation; not permanent supply
    interval_ms = 1000,
    confirm_samples = 3,
    calibrated = false,  -- raw diagnostic only; never assert DRY/WET until calibrated
    valid_min_v = nil,    -- after dry/wet/open/short measurements
    valid_max_v = nil,
    -- From the Nov 13 19:37 test: dry near 0.002 V, immersed 1.78-2.13 V.
    -- Provisional *bench* starting points only: wet_on_v=1.0, dry_off_v=0.10.
    -- Keep nil/calibrated=false pending open/short tests and actual lake-water samples.
    wet_on_v = nil,      -- rising threshold for WATER DETECTED when wet_above=true
    dry_off_v = nil,     -- lower threshold for confirmed DRY (hysteresis)
    wet_above = nil,     -- true/false based on measured polarity
}
