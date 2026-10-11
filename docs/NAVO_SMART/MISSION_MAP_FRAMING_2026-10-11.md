# Mission map framing — 11 October 2026

The Missions toolbar now exposes a compact route overview button outside the map.
It remains accessible when the stop editor is open or the map is expanded. It
closes the editor and fits all current mission destinations, the live boat and
HOME if the selected final action is RTL. The map centre control provides the
same overview when a mission exists, without adding another toolbar row. BOAT
restores the existing live follow behavior.

Accepted route START automatically requests overview framing. This changes only
the viewport; it sends no vehicle commands and changes no mission data. Overview
turns live follow off so telemetry does not immediately replace the framing.

Area Scan frames its generated lanes, excluding the inactive point/route draft.
Its HOME inclusion follows its own final action. Invalid coordinates are ignored;
an empty or recorded-replay mission cannot trigger live framing. Single coincident
points receive a local 40 m extent. QtPositioning computes the geographic bounds,
including date-line crossing, and a zoom margin leaves space around the markers.
Unrelated fishing points, fish detections and lake history do not enlarge the view.

Validation: real Qt 6.8.3 Location projection using the offline itemsoverlay plugin
passes route/scan/boat/HOME, single point, date line, invalid coordinates, replay
isolation and active-route framing in portrait and landscape. The production
Missions layout with substituted map/hardware checks toolbar signal dispatch and
retains hide/reopen, START, PAUZĂ/HOME and link-loss checks at 236/320/480/900 px.
Controller regressions: 51 audit and 19 route scenarios. Physical G20 viewport and
live boat acceptance remain pending; these tests do not establish either.

Android #836 on the preceding commit passed installed emulator acceptance. New
changes require their own Android workflow; PR #20 remains draft and unmerged.
