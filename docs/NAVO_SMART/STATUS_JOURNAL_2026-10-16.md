# NAVO SMART status and journal completion — 16 October 2026

## GitHub baseline verified before this update

- Main: `b4f4a2d`. Current application integration is still in draft PR #20,
  `856347f`, not merged. Android #847 (`38659695768`), Kogger #111,
  sonar display #94 and core #149 all completed successfully on that head.
- Replay annotations are implemented, followed by the fishing journal, real QGC
  offline-download controls and opt-in sound/voice alerts added on 15 October.
  See JOURNAL_OFFLINE_ALERTS_2026-10-15.md for the existing behavior and limits.
- Draft PR #21 (`23f1ac2`) is a strict descendant of PR #20 with six additional
  H743 V3 migration/service commits. Kogger #117, sonar #103 and core #161 are
  green on that head. A new Android build had not run on its branch: the Android
  push filter named the old integration branch, and the PR targets that branch
  rather than main. This change enables push builds for `fix/**` with the existing
  per-branch cancellation policy. New-head validation must still finish.

Work continues on PR #21, retaining all PR #20 features and the newer hardware
migration. Neither PR has been merged by this update.

## Journal completion

- Capture entries now accept optional species (80 characters), numeric weight in
  kg and bait/lure (120 characters). Baiting entries accept bait/lure. All retain
  the original observation text and frozen time/GPS/depth/temperature context.
- The form accepts decimal comma or point and up to three decimal places. Blank
  weight means unknown, never zero. Backend accepts only finite numeric weight
  >0 and <=1000 kg; text, booleans, zero, negatives and non-finite values fail
  without changing existing data. The upper bound is a data-entry limit.
- Older callers that omit structured keys preserve existing applicable values.
  Explicit empty species/bait or null weight clears the corresponding value.
  Changing the entry kind removes inapplicable fields. Existing free-text notes
  remain unchanged and are not parsed into measurements.
- Trip summary shows elapsed duration, entry counts by type, weighed-entry count,
  recorded total and maximum weight. Counts represent manual entries, not verified
  fish detection or multiple fish inferred from a note. Unknown/string weights do
  not enter totals. Type filters affect the list, not the whole-trip summary.
- The scrollable editor keeps Save/Cancel outside its content. Selecting another
  trip closes the editor; a stale save cannot be attached to a different trip.
  Existing replay/lake/new-entry/end-trip guards remain in place.
- Persistence uses the existing single atomic catalogue. No duplicate store,
  automatic hopper action, live detection, export or cloud service is added.

## Validation

- Compiled Qt 6.4.2 persistence suite: five tests pass, including structured field
  validation, restart, omitted/cleared metadata, reclassification, immutable source
  context, failed-write rollback and all existing catalogue migration/deletion tests.
- Real Qt 6.8.3 journal UI passes at 236/320/900 px: decimal comma, blank and invalid
  weights, Save placement, mixed legacy/structured summaries, filters, frozen source
  context, stale-trip guard, replay/lake guards and failed-save retention.
- 56 audit regressions, V3 route/hopper checks and 20 route scenarios pass. Existing
  hardware safety, offline-manager UI and replay-note UI checks also pass locally.
- New-head CI/Android results must be checked after publication. Local component
  tests and the previous-head APK do not establish installed acceptance of this head.

## Remaining work, in priority order

1. Complete new-head Android build and installed runtime checks including V3 changes.
2. On G20: create/edit/close a journal trip, restart and verify retained data; download
   a real map region and test every requested zoom offline after restart; confirm
   Romanian speech engine, sound output and volume behavior.
3. Complete portable offline lake archives if required: current base-map tile sets
   and NAVO lake checkpoints are separate. Coverage is not guaranteed by a green
   download button, and no atomic combined archive/export is implemented.
4. Validate H743 V3 onboard service, sensors, telemetry freshness, UM982, live Kogger,
   hoppers/lights/RC overrides and loaded-boat mission/energy behavior physically.
   Pin/configuration documentation is not evidence of tested wiring or calibration.
5. Fish alerts only after detector validation; calibrated bottom classification and
   steering acceptance remain physical-validation work. Camera hardware is separate.
