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

## Settings V3 — second approved NAVO design (28 Oct 2026)

Implemented in this same draft PR in response to the approved cyan/navy Settings mockup:

- \`NavoSettingsV3.qml\`: five working navigation tabs (\`General\`, \`Unități\`, \`Avansat\`, \`Integrare\`, \`QGroundControl\`), high-contrast palette, compact sections, pinned accessible **Salvare** action while scrolling. Replaces the old oversized Settings content inside \`NavoDashboard.qml\` without changing other dashboard pages.
- \`NavoEthernetSettings.qml\`: two bordered, compact Camera/Kogger cards with original editable host/port/transport/protocol settings; video player Preview and green ▶ / red ■ controls remain inside the Camera panel. Retains endpoint persistence, manual connection/disconnection and local LAN discovery. **Kogger runs over Ethernet** in this codebase; a mock serial/baud chooser was intentionally not added.
- \`NavoAlertSettings.qml\`: real alert sound/voice switches, compact volume slider, test/stop actions, short status fields and expandable context help.
- \`NavoSteeringPanel.qml\`: real STEERING availability, confirmation and HOLD stop; short expandable safety help. **No invented sensitivity slider**: tuning is a H743/ArduPilot task.
- \`NavoG20Settings.qml\`: compact Advanced tab, dark inputs and context help behind an info button; preserves mapping controls and safeguards.
- \`Unități\` and \`QGroundControl\` use the existing \`mainWindow.showSettingsTool()\` hook, when exposed by QGC. No imitation of vehicle setup/parameter tuning.
- Camera/Kogger endpoints are committed by \`saveEndpoints()\`; QtCore.Settings already persists Energy preferences on edit. Saving does **not** bypass energy-confirmation calibration.
- Accessibility: primary text \`#eff9ff\` on \`#061827\` (WCAG luminance contrast approx **16.8:1**); secondary text \`#c1d7e6\` approx **12.1:1** on the same surface. Native Qt dropdown rendering and G20 visual measurements require device verification.

### Additional validation pending

- [x] Structural static checks of the new settings, wiring, balanced delimiters and registered QML resources.
- [x] Static regression assertions added to \`tests/audit-regressions.mjs\`.
- [ ] Real Qt/QML component loader and screenshots on G20/tablet — **not run**.
- [ ] Android emulator smoke/Accessibility inspection — **not run**.
- [ ] Verify \`mainWindow.showSettingsTool()\` on this pinned QGC release.
- [ ] Video test, Kogger LAN, audio test and H743 STEERING on connected hardware — **not run**.
- [ ] Confirm exact appearance at small G20 resolutions and Android font scaling.
- [ ] APK build — **not authorised; do not trigger**.

All changes remain exclusively in the isolated **Draft PR #29**. \`main\` is unchanged.

## Journal, Bălțile mele, Hărți offline — consistent NAVO V3 style

The 28 Oct 2026 design direction is now applied to three additional menus in the **same Draft PR #29**:

### Jurnal de partidă — \`NavoFishingJournal.qml\`
- Compact navy/cyan header, top tabs \`Partide\`, \`Însemnări\`, \`Statistici\`.
- Properly boxed trip chooser, editable notes/catches/bait, and statistics computed from real persisted trip entries.
- All existing forms, timestamp/GNSS capture at entry start, validation of optional catch weight, \`saveFishingEntry\`, finish and delete confirmation remain unchanged. The editor fields and dialogs are now styled with high-contrast navy/cyan controls.
- The \`pendingBaitJournalCount\` recovery banner in \`NavoDashboard.qml\` also uses the NAVO palette; no change to recovery behavior.

### Bălțile mele — \`NavoDashboard.qml\` and \`NavoMyLakes.qml\`
- Both the sidebar's **actual Bălțile mele page** and the detailed management popup are redesigned, avoiding a half-updated UI.
- Main page tabs: \`Bălți salvate\`, \`Baltă activă\`, \`Administrare\`. Compact lake creation and selection, clear controls for rename/delete.
- Manager popup tabs: \`Prezentare\`, \`Sesiuni sonar\`, \`Acțiuni\`; real counts for sonar samples, fishing spots, fish detections and Area Scan progress.
- Existing per-lake persistence, session opening, restore/reload, map and 3D navigation, fishing spots and \`resumeLakeScan\` signals remain. Delete/rename confirmation is preserved.

### Hărți offline — \`NavoOfflineMaps.qml\`
- Tabs: \`Descarcă\`, \`Zone salvate\`, \`Informații\`.
- Readable section for selecting a real map region, tile type, zoom range, name, tile count, download estimate and explicit \`Descarcă zona\` action.
- Saved-zone cards include live progress, \`Pauză\`/\`Reia\`, \`Afișează\` and confirmed \`Șterge\`, with the original QGC map manager operations.
- The 5,000-tile/setting cap, invalid-area protection, duplicate-name protection, asynchronous creation tracking and offline delete safeguards remain unchanged.
- Help text is in its own tab, not spread across the editing screen.

### Added checks / not yet validated
- [x] Static review of tab IDs, backing functions, popup states, CMake entries and UI references.
- [x] New static regression assertions for journals, lake library and offline downloads in \`tests/audit-regressions.mjs\`.
- [ ] Qt QML component load and Python/PySide6 UI regressions (\`tests/fishing-journal-ui.py\`, \`tests/offline-maps-ui.py\`) **not executed**.
- [ ] Android smoke at actual G20 screen size and accessibility text scaling **not executed**.
- [ ] Check saved-lake restore with actual sonar and offline imagery **not executed**.
- [ ] Full APK build/merge **not authorised**; all commits include \`[skip ci]\`.

All menu navigation remains backed by existing NAVO controllers and persisted data. No fabricated readings, sonar sessions, fishing catches or downloaded map tiles are introduced.

### Responsive follow-up and preservation audit (28 Oct 2026)

- Journal header becomes two rows on narrow screens and trip action buttons wrap rather than leaving the NAVO card. This preserves the production `journalEntryEditor`, `journalEntrySave`, filtering and safety gates.
- Offline map header, zoom controls and the download action use responsive GridLayout breakpoints (narrow/standard/tablet). All map-type, zoom, quota, download, pause/resume, show and delete actions still call the pre-existing map-engine manager.
- Direct comparison with the `main` versions confirmed **18 unchanged core function bodies** across the three modules: 6 journal functions (`tripSummary`, `entryDetails`, `findTrip`, `findActive`, `beginEntry`, `saveEntry`), 4 offline functions (`estimate`, `useRegion`, `beginDownload`, `checkCreated`) and 8 lake functions (`sessionsForLake`, `selectLake`, `refreshSelected`, `addLake`, `beginRename`, `beginDelete`, `renameCurrentLake`, `deleteCurrentLake`).
- Extended static regression scenarios for narrow-screen layouts and confirmation safeguards are committed in `tests/audit-regressions.mjs`, **but have not been executed**.
- Source-level delimiter checks were performed on the three QML menus; these are **not** substitutes for Qt's QML parser, visual testing or user acceptance.
- No workflow, Android APK compilation, emulator or hardware test has been started; PR #29 remains Draft and `main` is unchanged.
