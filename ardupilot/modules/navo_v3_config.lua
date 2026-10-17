-- NOT A PIN MAP TO FLASH. Fill only after reviewing the boat .param and Rev F.
-- Copy modules into APM/scripts/modules, service into APM/scripts.
return {
    enabled=false,
    gcs_system=255, gcs_component=190,
    hold_ms=900,
    -- Dedicated outputs, 1-based. Must be FUNCTION=135 (constant TRIM),
    -- TRIM=closed, and MIN/MAX contain both positions. Never motor/rudder.
    hoppers=nil, -- {{output=...,closed=...,open=...},{output=...,closed=...,open=...}}
    lights=nil, -- {head_gpio=...,position_gpio=...}; externally reviewed GPIO ownership
    temperature=nil, -- {adc=...,supply_v=3.3,series_ohm=...,nominal_ohm=10000,beta=3950,ntc_to_ground=true}
    water=nil, -- {adc=...,exc_gpio=...,settle_ms=100,valid_min=...,valid_max=...,threshold=...,wet_above=true}
    -- DHT11 interior temperature/humidity: documentation-only placeholder.
    -- NOT a supported Lua GPIO reader: requires microsecond timing + checksum.
    -- Never assign a GPIO or enable before pinout/driver/3.3V validation.
    interior_dht11=nil, -- {gpio=..., supply_v=3.3} only after validated driver
    rgb=nil, -- {output=...,count=1,order="GRB"}; verify WS2811 timing/color order
}
