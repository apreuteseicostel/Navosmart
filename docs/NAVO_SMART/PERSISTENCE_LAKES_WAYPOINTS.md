# Persistence / My Lakes / waypoints

## Canonical storage
Do not create a second waypoint/fishing-spot store. Existing persistence is the canonical path.

NavoFishingSpots stores id, name, latitude, longitude, depth, temperature, note, sonar evidence, color and createdAt. Waypoint names persist separately for mission waypoint labels.

NavoScanCoordinator checkpoint schema v2 persists lake state including sonar samples, fishing spots, fish detections, waypoint names, bathymetry and mission/scan state. Autosave interval is 5 s. Active lake is restored from session settings at startup.

## Required user behavior
Saved points have editable names such as lanseta verde / lanseta roșie and preserve GPS + depth + temperature + timestamp. My Lakes must restore the complete lake, not only a marker. Resume must restore unfinished Area Scan state.

Target smoke scenario: create lake -> scan -> save fishing spot -> restart app -> load lake -> Resume.

## Durability audit
Audit immediate checkpoint behavior for rename/color/remove and baiting-created spots. deleteLake persistence/error handling must not report success if durable save failed. Avoid duplicate persistence implementations.
