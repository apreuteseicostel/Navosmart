# Replay notes, fishing journal, offline maps and alerts — 15 October 2026

The agreed order is replay annotations → fishing journal → complete offline maps
→ sound/voice alerts. Fish alerts remain excluded until detector validation.
PR #20 stays draft; this update does not establish installed G20 acceptance.

## 1. Replay annotations

Existing delivered-column annotations were retained. The original head d5c23e07
passed Android #843, Kogger #107, sonar #91 and core #145. The production dialog
regression and compiled recording/annotation roundtrip are checked again locally.
See REPLAY_ANNOTATIONS_2026-10-11.md for source association and format limits.

## 2. Fishing journal

The sidebar adds **JURNAL**. Select an active lake, start a named trip, then add
observations, catches or baiting notes. The three types are manual entries; a note
labelled “Nădire” does not command a hopper or claim a physically verified drop.
One trip may be active at a time, and that state survives restart. Finish requires
confirmation. Historical entries can be edited or deleted, and whole-trip deletion
is confirmed. Closing a trip prevents new entries, while text/type corrections
preserve its original time/position/depth/temperature.

New entries freeze their context when the editor opens. GPS requires the actual
vehicle coordinate, a connected link and fix >=3; otherwise GPS is unknown.
Replay blocks new trips/entries. Changing the active lake or replay mode closes the
editor. Adding an entry on a different lake from the trip is blocked. Depth and
water temperature are saved when available; no live GPS is borrowed for replay.

Trips share the existing atomic `navo/catalogV1` QSettings catalogue with lakes and
bathymetry sessions. Failed writes restore both in-memory state and the pending
QSettings cache. Invalid catalogue structure is protected from overwrite. Old
catalogues without `trips` migrate on their next successful save. Limits: 200 trips,
1,000 entries/trip, 1,000 text characters/entry and 5 MiB total trip JSON. Historical
lake names/entries remain after deleting a lake. No cloud sync/export is added.

## 3. Offline maps

From **HARTA**, frame a region, then use **Straturi → Salvează zona offline**, or
open **HĂRȚI OFFLINE** in the sidebar while the map is visible. The four viewport
corners determine the download bounds. Dateline-spanning/invalid/polar regions
are rejected. Choose the map provider/type, minimum/maximum zoom and a unique name.
The UI estimates tile count/size and limits a request to the smaller of the QGC
configured limit and 5,000 tiles. Size is an estimate, not a free-space guarantee.

This is a client for the **real QGC v5.0.7 QGCMapEngineManager/QGCCachedTileSet**:
`updateForCurrentView`, `startDownload`, actual tile-set counts, cancel/resume and
confirmed per-set deletion. It does not introduce a second tile cache. The default
shared cache cannot be deleted from this page. A set is shown as complete only
when QGC reports all its tiles saved. Downloads continue in the shared manager
when navigating away. Failed/partial sets remain visible and resumable. The saved
set's type is applied to flight-map settings before showing its centre/zoom.

QGC's persistent tile database supplies the regular flight map for downloaded
bounds, type and zooms without internet. Existing NAVO lake checkpoints separately
hold spots, sonar samples, native surface meshes and mission drafts. QGC terrain
“elevation” download is disabled here because it is not lake bathymetry. Base-map
sets and lake checkpoints are separate stores; no atomic combined portable archive,
cloud synchronization or new tile format is claimed. Native surface completeness
still depends on valid sonar coverage. Full offline acceptance requires downloading
a real region, restarting Android and inspecting every requested zoom in airplane
mode, together with saved native bathymetry/spots. This has not been run locally.

## 4. Sound and voice

**SETARI → Alerte sonore și vocale** adds separate opt-in sound/voice switches,
volume and an explicit test. Defaults are off. A bundled short PCM tone works
without a remote sound file; Qt TextToSpeech uses the device engine with Romanian
locale requested. Device engine/language/audio availability still needs checking
on G20; an unavailable speech engine leaves the visual notice and optional tone.
These switches control NAVO's new alerts, not QGC's existing system announcements.

Telemetry conditions: battery <=20%, link loss, missing GPS, confirmed water and
battery temperature >=55 °C. A successful software baiting cycle is announced as
cycle completion, not as proof of physical hopper movement or arrival HOME.
Each condition fires on activation, rather than every telemetry update. Unknown
measurements do not re-arm it. A ten-second per-key cooldown, bounded eight-item
queue, water/temperature priority, 20-second stale-item expiry and 2.5-second audio
spacing limit alert bursts. Recovered conditions remove their queued notices.
Changing vehicles or entering replay discards queued audio. Replay suppresses all
automatic notices; the explicit settings test remains available. No controller or
servo command is introduced by this notification module.

## Validation and remaining acceptance

- Compiled Qt 6.4.2 persistence: journal start/end, source data, GPS loss, immutable
  context on edit, restart, deletion, lake deletion retention and failed-write
  rollback pass, alongside the existing catalogue migration/deletion suite.
- Production journal and offline QML render at 236/320/900 px. Journal checks freeze
  the source context, replay/lake guards and failed-save editor retention. Offline
  checks use an explicit API double matching pinned QGC properties/model roles;
  they cover bounds, limits, duplicate names and asynchronous creation. They do
  not prove network download or native tile-cache reload.
- Alert tests cover edge deduplication, unknown telemetry, replay and mute policy;
  actual audio/settings QML compile. Audible output is not established on the host.
- Existing controller/route/steering/G20 and production Missions, map framing,
  saved-point, steering, recording and replay-note UI regressions pass locally.
- CI now runs the three new component checks. Android UI smoke visits JURNAL and
  HĂRȚI OFFLINE. New-head Android build, installed navigation and all CI results
  must be checked after publication; earlier-head green runs are not new-head proof.

Hardware acceptance remains: G20 sound/voice/locale, airplane-mode map coverage at
all saved zooms after restart, journal create/edit/restart on Android, actual H743/
UM982/Kogger/Nano/servo behavior and physical boat trials. PR remains unmerged.
