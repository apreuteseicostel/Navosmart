-- NAVO SMART V3 RevF: standalone read-only hull-water monitor.
-- Disabled until J12 continuity/wiring and H743 assignments are verified.
-- J12.1 GND, J12.2 S8/PD13/GPIO57, J12.3 CU2/PA7/ADC7 (PROPOSED, not proven).
-- Never copy example thresholds: measure dry/wet/open/short voltages on the actual board.
return {
    enabled = false,
    adc_pin = 7,          -- J12.3 -> CU2 / PA7 (if physically wired)
    exc_gpio = 57,        -- J12.2 -> S8 / PD13 (if physically wired)
    settle_ms = 120,      -- pulsed excitation; not permanent supply
    interval_ms = 1000,
    confirm_samples = 3,
    calibrated = false,  -- raw diagnostic only; never assert DRY/WET until calibrated
    valid_min_v = nil,    -- after dry/wet/open/short measurements
    valid_max_v = nil,
    threshold_v = nil,
    wet_above = nil,     -- true/false based on measured polarity
}
