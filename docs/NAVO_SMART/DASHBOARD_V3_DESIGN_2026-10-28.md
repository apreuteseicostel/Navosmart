# NAVO SMART — Dashboard V3 Design Preview (28 Oct 2026)

Status: **DRAFT / NOT BUILT / NOT HARDWARE-TESTED.** Design implementation sourced from the four 16:9 mockups approved for review in the NAVOMODEL conversation (Home, Battery, Temperature and Mode), plus the earlier GNSS mockup.

## Change set in this branch

- **Brand/Home:** the header keeps existing navigation architecture but adds a yellow boat/N icon candidate and the exact Romanian sub-brand **Pescaru' lu' Pește**. Clicking the logo returns to HARTA and reveals **build and design by Costel Apreutesei**. Existing compact vertical navigation and the full map remain intact.
- **GNSS popup:** dark navy rounded surface, cyan hairline outline, structured telemetry rows, smaller close control, compact **Verifică GPS** button. Only facts from MAVLink; no fake dual-antenna identification.
- **Battery popup:** click BATERIE to view available QGC/MAVLink values: pack percent, voltage, current, derived V×A power, and battery consumption when reported. Four-cell average is *calculated from total voltage*, not measured from individual cells. BMS health, cell balancing and endurance are **not inferred**. All missing/stale data displayed as **--** or clearly uncalibrated.
- **Temperature popup:** click TEMP for session-only graph of the **H743 battery NTC** reading (not water temperature). Collects real fresh samples at most once every 10 seconds for up to 60 minutes while the app is running. Min, max and average computed only from those samples. Does not fabricate a 21°C sample curve or persist history.
- **Mode popup:** click MOD for read-only OFF / MANUAL / AUTO highlighting based on the current G20 **CH5 PWM**. Low <1300, middle 1300–1699, high >=1700 μs. The display reports the **confirmed H743 flight mode separately**. It does not change flight modes, arm/disarm, command AUTO, stop the motor or bypass H743 failsafes. **G20 channel 5 and switch direction must be verified in the transmitter Device Tool, H743 RC telemetry and ArduPilot MODE_CH before claiming control.** OFF describes switch position only, not disarm.
- **Typography/colors:** '#071926' navy, '#20d9ed' cyan, '#31d6a5' mint, yellow accent, thin borders, rounded 9–15px panels; retains NAVO's existing icon-only navigation to avoid covering the map.

## Important design mismatches resolved conservatively

The four reference images are **concept art**, not captured MAVLink data. Battery example **25.1 V** in the mockup is inconsistent with the configured **4S Li-ion / maximum 16.8 V** system, so no numeric demo values are inserted. Battery health and servo-rail measurements are not available from the existing QGC Battery fact without additional hardware sensing.

**Launcher icon:** conversations reference the owner's previously selected **Variant 5 (boat + N)**, but its original file/Android adaptive-icon assets are not in this repository. This PR adds **custom/icons/navo-brand.svg** as a *dashboard-only candidate* consistent with the references. It **does not overwrite the launcher/splash icon** or claim to reproduce Variant 5 exactly. Use the original approved asset for that separate packaging change.

## Validation / approval

- [x] Implement isolated QML panels and register resources in custom/CMakeLists.txt.
- [x] Preserve map/sonar/mission/baiting control paths; new panels are read-only.
- [x] Add static acceptance assertions to tests/audit-regressions.mjs.
- [ ] Run Qt `qmlformat`/QML loader validation after user authorizes tests.
- [ ] Review real G20 screen at compact resolution; ensure pills scroll and modals fit.
- [ ] Check CH5 PWM ranges and corresponding actual H743/ArduPilot modes, on bench.
- [ ] Confirm original Variant 5 launcher/splash artwork before touching Android resources.
- [ ] Build Android / emulator / APK **only after explicit user instruction**.
- [ ] Merge to main only after validated build and user approval.

> All commits in this draft branch have [skip ci]; no Android build was requested.
