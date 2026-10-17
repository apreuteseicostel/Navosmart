# Replay annotations — 11 October 2026

Sonar PRO adds **Adnotează coloana afișată** and **Note replay** to its replay menu.
The editor captures the currently displayed CHART column, including its delivered
replay anchor and processed bottom/temperature when available. It pauses running
replay and restores playback on close only if it was previously running and the
same source is still open. Already-paused replay remains paused. A failed save
keeps the editor and its captured context available for retry.

The note catalogue exposes text, source position and recorded GPS/depth, with edit
and confirmed delete. Annotations are separate from live fishing points, lake
samples and missions. They issue no vehicle or servo commands and never borrow
live vehicle GPS. GPS loss stays unknown. They also work at EOF while replay mode
remains open. Notes are not exported into or embedded in the original sonar file.

## Anchors and persistence

The replay backend publishes its anchor **before** feeding the corresponding raw
bytes, rather than using the file cursor (which can already contain a pending
future record). Sonar PRO copies that anchor synchronously alongside its completed
CHART column. The note keeps the raw delivered-frame/block ordinal plus the CHART
sequence, and the NAVO record reception milliseconds. A NAVO raw block may contain
several sonar frames; the sequence distinguishes the selected displayed column.
KLF uses its parsed frame ordinal and marks reception time unavailable (-1); it
is not assigned a fabricated wall-clock or NAVO recording timestamp.

Versioned JSON lives in app data under `replay-annotations`. QSaveFile commits
updates atomically with direct-write fallback disabled. In-memory notes update
only after successful commit. Limits: 500 notes/source, 1,000 UTF-16 text units/note,
1 MiB sidecar. Invalid or unreadable existing sidecars remain untouched and display
an error; playback remains available. Stop/source changes clear annotation context
and close stale editors. The recording bytes are never modified.

Association uses a bounded SHA-256 fingerprint of source URI, size, reported
modification time and up to 64 KiB at the replay start position. This avoids hashing
large recordings on the UI thread. It is a source/version association, not a full
content integrity proof: moved/renamed files get a new association, and content
providers with no reliable modification time cannot distinguish a same-size
replacement that preserves the fingerprinted prefix. Automatic migration, cloud
sync, annotation export and jumping playback directly to a note are not included.
The catalogue identifies notes by frame/column/time; replay still starts normally.

## Validation

- Compiled Qt 6.4.2 production replay/recorder test: before-bytes anchor publication,
  frozen saved pose, NAVO/KLF save/reopen/edit/delete, source isolation, GPS loss,
  unknown KLF reception time, untouched original bytes, oversized text rejection,
  corrupt sidecar protection and failed-write rollback. Existing archive checksum,
  malformed input, pause/backpressure and bounded elapsed pacing checks pass.
- Real Qt 6.8.3 editor/catalog at 236/320/900 px with an explicit backend double:
  frozen column, pause restoration, edit/confirmed delete, failed-save retention
  and stale source/live guards. Production Sonar PRO history test verifies the
  captured anchor does not change when replay advances. Resource packaging checks
  and the existing 51 controller/20 route regressions pass.
- Core CI runs the new UI check; Kogger CI runs the expanded native test. Final
  Android build and installed acceptance still require the new workflows. These
  local checks do not claim G20/device acceptance of annotation controls.

PR #20 stays draft and unmerged. Next planned stages remain: fishing journal,
complete offline maps, sound/voice alerts, then fish alerts after detector validation.
