# NAVO SMART — Sonar GPS and bathymetry sample integrity
Date: 16 Nov 2026. Implementation scope: software-only, no H743/RC/motor commands.

## Audit finding

The existing SONAR PRO already supports live echo-column marking, live Kogger
dataset/3D integration, sonar replay notes and lake-specific fishing spots.
The experimental B and C renderers already have independently buildable APKs
(PR #92/#93); this patch does **not** replace either renderer or merge the
large sonar stacks.

Three validation gaps were found in main:

1. `NavoSonarEthernet.qml`'s legacy completed-CHART geosample could publish
   a boat coordinate merely because `coordinate.isValid` was true, even if
   GNSS fix fell below 3 or QGC's MAVLink link was lost. The recorder/native
   adapter already checked fixes, but the legacy path did not.
2. `NavoSonarMapping.qml` converted `lat:null`, `lon:null` or
   `"0"` via `Number(...)` into valid zero coordinates; similarly an
   accidentally typed depth could be accepted.
3. `NavoPersistence::addSonarSample` checked only the *presence* of
   `lat`, `lon`, `depth`; missing-value variants could enter exported
   raw sample archives.

## Changes

- One shared `liveGpsReady()` predicate for GPS fix >=3, valid numeric
  latitude/longitude, connected QGC link and non-replay state. Both live
  recorder attachment and the legacy CHART-to-geosample path use it. Invalid
  GPS does **not** stop normal sonar echo display or record raw CHART bytes;
  it merely marks associated GPS absent.
- Bathymetry sample ingress now requires actual numeric finite lat/lon/depth
  within WGS84 bounds and positive depth. An actual numeric (0,0) remains
  allowed (valid real-world location); only implicit coercion is rejected.
- Persistent raw sonar archive applies the same gate before appending.
  Strings, booleans, nulls, infinity, NaN, out-of-range coordinates and
  nonpositive depth are rejected.

## Limitations

- GPS quality/fix >=3 does not prove RTK correction or timestamp
  synchronization between sonar ping and GNSS. Current live chart positions
  describe the most recent accepted QGC coordinate at host reception.
  Do not advertise centimeter precision or exact transducer-time anchoring.
- Does not change Kogger 256-shade rendering, Sonar PRO B/C UI,
  KLF whole-file index, existing saved data or MAVLink/autopilot behavior.
- Previously saved malformed samples are not silently deleted or rewritten.
  This patch prevents new corruption. Existing data should be audited before
  conversion to map tiles or navigation points.
- No fabricated GPS fallback for replay: recorded coordinates remain separate
  from live boat telemetry.

## Tests

- `node tests/audit-regressions.mjs` — missing/null, coerced GPS/depth,
  legitimate numeric zero, GPS fix loss, replay and GCS link loss.
- `tests/persistence/persistence.cpp` — real C++ `NavoPersistence`
  rejects the same inputs, retains valid points and emits change only
  for accepted samples.
- NAVO V3 core, Android arm64 build, sonar replay and G20/S26 test
  required on the exact commit; run CI before merging.
- Bench with a *disarmed* boat and real Kogger: verify geosamples stop
  receiving GPS coordinates when fix/link drops and resume after recovery;
  display can continue without marking sonar locations.
- On water: compare selected echogram point on map versus an independent
  waypoint observation. GPS latency remains uncalibrated.

## Integration dependencies

- Independent of Draft #114 Digital Anchor and #115 H743 failsafe readback.
- Independent of Kogger PRs #92/#93/#98/#99/#101 and native 3D #78;
  review competing sonar patches before final integration.

Keep Draft until CI and device field validation.
