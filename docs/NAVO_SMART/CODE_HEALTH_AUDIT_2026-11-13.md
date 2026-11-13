# NAVO SMART — code health audit (2026-11-13)

**Baseline:** `main` after integration of #63, #64 and #65; audit branch `audit/navo-code-health-20261113`.

## Repository integration inventory

- At the beginning of this review GitHub listed **93 branch refs and 18 open PRs**. A branch ref is not necessarily unmerged work: older release, integration, feature and fix refs coexist.
- PR **#63** integrated the previously tested commit chain #49–#62 into `main` (merge commit `3039af63c8b2189a7d267b4591dce8004ca1da95`). PR **#64** added journal JSON export (`b0f47ff0aff5fd1d2b73033864e60a67a5599ce2`); PR **#65** added portable backup/restore (`6cb37fcc47627c091fbf9bfaa2b9abf4a8044206`).
- Remaining stacked PRs #50, #51, #53, #54, #55, #57, #61 and #62 were independently checked: their HEADs were already ancestors of `main` (ahead=0). They were closed as superseded by #63; source branches were **not deleted**. GitHub had automatically closed other included PRs.
- **#66 (stable Android signing/update workflow) remains open**. Main distribution builds would require a durable signing keystore/password and pinned certificate fingerprint. Do not merge this workflow without ensuring those repository settings exist; keep private material outside Git.

This inventory verifies the **open PR series**; it does not certify that every old, unreviewed branch among all 93 is safe to delete. Before deleting any branch, compare its ancestry and file diff to current `main`.

## Observed runtime architecture

| Component | Existing data/event mechanism | Timer / candidate | Assessment |
| --- | --- | --- | --- |
| H743 telemetry | `Vehicle::mavlinkMessageReceived` | 1 s freshness notification in `NavoH743Telemetry.cc` | Retain freshness detection; do not poll for incoming MAVLink packets. |
| GNSS heading | MAVLink callbacks | 500 ms validity refresh in `NavoGnssHeading.cc` | Retain until invalid-GPS fallback timing is measured. |
| Connectivity | Link/heartbeat events | 1500 ms discovery/status refresh and 300 ms queued connect dispatch in `NavoConnectivity.cc` | Essential reconnection path; profile, do not remove blindly. |
| Live sonar | `NavoEthernetTransport.onBytesReceived` and decoder callbacks | 500 ms freshness timer in `NavoSonarEthernet.qml` | **Fixed in this PR:** run only while live transport is connected and replay mode is off. |
| Sonar bathymetry | Decoder `onEchoSamplesChanged` / native chart service | 2 s `requestReplaySurface()` while connected | Investigate duplicate/redundant mesh requests using count and viewport instrumentation before changing behavior. |
| Replay bathymetry | Sample ingestion | `NavoDashboard.qml` rebuilds replay grid every 2 s while replaying | Candidate for dirty-revision/event-driven update; requires output equivalence tests. |
| IP video | `videoSink.onVideoFrameChanged` | 500 ms stall watchdog + one-shot retry in `NavoVideoPlayer.qml` | Retain stall detection, verify no duplicate concurrent player sessions. |
| G20 RC input | `onRcChannelsReceived` | 250 ms expiry check | Safety-related. **Do not remove** without bench/HIL acceptance. |

**Why one timer was changed:** with no live sonar and no replay, the old `freshness` timer changed `clockMs` twice per second indefinitely. `echoFresh` already requires live, non-replay data and disconnect resets timestamps. Gating the timer on `transportObject.connected && !root.replayMode` removes unnecessary QML activity without replacing data-driven decoder updates.

## Duplication and dead-code audit queue

1. Build a reference graph from `custom/CMakeLists.txt`, QML imports/instantiations, and C++ QML registrations before considering removal. Multiple implementations are not necessarily duplicates.
2. Review `NavoAndroidFpvPlayer.qml`, `NavoQtVideoPlayer.qml`, and `NavoVideoPlayer.qml` together: preserve intentional fallback between the Skydroid and Qt backends.
3. Review `NavoBathymetryModel.qml`, `NavoBathymetryHDModel.qml`, native overlay and replay models: preserve format/storage responsibilities and offline compatibility.
4. Check stale or overlapping UI components, unused QML properties and unreachable navigation paths; require evidence from runtime code paths, not filename suffixes.
5. Check long-running timers and signal connections for orphan listeners, excessive invalidations and replay/live cross-talk. Keep autopilot failsafe and H743 command logic unchanged.
6. Validate the new backup and journal picker on Android/G20; native/Qt core tests passing are not equivalent to completed device acceptance.

## Tests and acceptance gates

- Included static regression: `tests/audit-regressions.mjs` enforces the sonar freshness-timer policy.
- PR CI must run `node tests/audit-regressions.mjs`, controller/UI tests, `qmlformat`/MOC and the ARM64 APK workflow. Review exact head SHA and job conclusions before merging.
- Profile disconnected idle, sonar-only, camera-only, and combined GPS+sonar+video under the same Android device and logging settings. Record CPU use, memory, UI frame drops, wakeups and reconnect counts; **do not claim performance improvement from a timer diff alone**.
- Test transitions: disconnect/reconnect sonar, live→replay→live, stale echo expiry, record/replay, app background/resume, G20 camera fullscreen close, loss of MAVLink/heartbeat.
- Keep in-place APK updating (#66) blocked pending stable signing key/certificate setup and successive same-key APK install-over-install test.
- Preserve recovery/backups, safety-critical modes and hardware actions. No branch deletions or hardware commands belong in a cleanup PR.

## Scope of this PR

- **Code:** stop the live sonar freshness watchdog when transport is disconnected or playback is replay-only.
- **Regression:** assert that this timer remains conditional.
- **Documentation:** capture current findings, open risks and the next measured cleanup tasks.
- **Not done:** deleting old feature modules, changing MAVLink/servo/ArduPilot behavior, guaranteeing Android/G20 acceptance, or merging PR #66.
