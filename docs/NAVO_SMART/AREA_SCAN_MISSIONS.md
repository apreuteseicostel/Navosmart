# Area Scan / missions

## Geometry
Rectangle and polygon selection on map. Rectangle is user-controlled with adjustable corners, live preview and dimensions in metres. Polygon requires >=3 points. Current safe generator rejects concave/self-crossing polygons until obstacle-aware connectors exist. Lawn-mower lanes alternate direction; lane spacing configurable; mission capped at 500 points.

Selection flow: map geometry -> lane generation -> ScanCoordinator checkpoint -> mission preparation -> QGC/H743 upload -> START/AUTO -> mission reached/progress -> Resume.

## UI/actions
Compact icons with tooltips: rectangle, polygon, prepare, upload/start, Resume, HOLD/pause, RTL/Home, STOP. Show progress, completed/total lanes, H743 waypoint and lane states. Bottom touch controls need adequate size/spacing. Support Șterge linii.

## Mission integration
NavoMissionUploader wraps QGC PlanMasterController/MissionController and keeps MissionSettingsItem at index 0. Upload verified only after MissionManager send completion; timeout 15 s. Vehicle change aborts upload. MISSION_ITEM_REACHED is filtered to vehicle sysid and autopilot component.

START requires valid link, Rover/Boat, verified upload, valid lake/GPS/coordinator state and required sonar state for READY/RESUME_READY. Start is confirmed by actual autopilot mode, not button press. Resume exports only unfinished lanes and may reverse first remaining lane when that endpoint is nearer.

HOLD pauses scan and vehicle. STOP checkpoints/pauses, invalidates uploader and HOLDs. RTL marks state and requests guided RTL. Hardware behavior remains unvalidated until real H743 test.
