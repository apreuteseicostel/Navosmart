# Map marker stabilisation

Display only: the yellow boat marker and the operator-to-boat display line use a filtered copy of `Vehicle.coordinate`. Navigation, mission geometry, saved fishing spots, bathymetry/sonar samples and controller inputs keep the original coordinate. Heading selection is unchanged.

The filter attenuates stationary jitter without a hard deadband or fixed position lock. Consecutive speed readings above 0.6 m/s or three coherent displacement samples reduce the smoothing time constant. Marker transitions last 250 ms. Large displacements and gaps over three seconds reset the estimator instead of preserving an old position. Longitude deltas wrap at the antimeridian; animation is disabled for a longitude wrap.

GPS1 `GPS_RAW_INT.h_acc` is read in millimetres and displayed in metres. Zero, missing extensions and UINT32_MAX are unknown, never inferred from HDOP. The optional accuracy circle is centred on the unfiltered GPS1 coordinate; it is reported GNSS precision, not a guarantee of boat position or EKF accuracy. It is hidden without fresh valid GPS1 telemetry. Stale markers dim and show `GPS vechi`; replay and vehicle changes reset visual state.

Validation: `node tests/map-visual-position.mjs` covers stationary jitter, slow coherent movement, consecutive speed evidence, turns, unknown accuracy, invalid inputs, gaps, antimeridian and display/controller separation. Existing audit regressions also run. Native Android compilation, Qt rendering and stationary/slow movement/turning device acceptance remain required; unit tests do not establish hardware positioning quality.

This branch is stacked on PR #49, commit 90da107c2f79e44dac76b4db52954cf7eb48ba89. It retains the steering/HOLD and Area Scan changes. No mode, parameter, actuator, transport or hardware commands are added. No manual APK build or merge is requested here.
