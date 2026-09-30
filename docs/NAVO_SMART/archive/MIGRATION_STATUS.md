# NAVO SMART — Migration & archive status

Date: 2026-09-30

## CANONICAL — use for ongoing engineering
- ../PROJECT_MASTER.md
- ../PCB_NAVO_SMART_V2_E1.md
- ../FIRMWARE_NANO.md
- ../H743_ARDUPILOT_UM982_GR01.md
- ../APP_NAVO_SMART.md
- ../APP_UI_REQUIREMENTS.md
- ../AREA_SCAN_MISSIONS.md
- ../PERSISTENCE_LAKES_WAYPOINTS.md
- ../BAITING_FAILSAFE.md
- ../SONAR_BATHYMETRY_3D.md
- ../SONAR_LAN_CAMERA.md
- ../ETHERNET_CAMERA.md
- ../SAFETY_INTEGRATION.md
- ../HARDWARE_BOM_POWER.md
- ../GITHUB_BUILD_WORKFLOW.md

## LIBRARY TEXT MIRRORED IN GITHUB
- ../library/NAVO_SMART_V2_Audit_Raport.md
- ../library/NAVO_SMART_V2_Baza_Proiectare.md
- ../library/BOM_JLC_legacy.csv
- ../library/Positions_All_JLC_Positive_legacy.csv
- legacy/NAVOMODEL_Audit_2026-09-16.md
- legacy/NAVOMODEL_RevD_Cerinte.md

## E1 WIP — important binary still in ChatGPT Library
- NAVO_SMART_V2_E1_WIP_30SEP2026.zip
Status: raw-byte materialization is not authorized by the current Library path, so it is NOT physically mirrored in GitHub. Do not claim otherwise.

## LEGACY BINARIES — retained in ChatGPT Library / temporary workspace
- NAVO_SMART_V2_E0_Prototip.zip — DO NOT FABRICATE; superseded by audit findings.
- NAVOMODEL_Arduino_v1.0.zip — historical; current editable firmware is in /firmware/NAVOMODEL_Arduino.
- NAVOMODEL_QGC_v0.1_sursa.zip — historical; current editable app source is in this repository.
- Positions_All_JLC.xlsx — historical placement workbook.
- Legacy Gerber/assembly packages and Rev.D drawings outside /NAVOMODEL remain historical inputs only.

## REFERENCE IMAGES IN LIBRARY
- Top-Down Black PCB Control Board.png
- Top-Down Electronics PCB on Wood.png
- UM982 Dual GNSS Boat Installation Guide.png
These are reference images, not electrical authority.

## RULE
Current engineering decisions in /docs/NAVO_SMART override legacy material. No E0/Rev.D manufacturing package is approved for fabrication. E1 fabrication approval requires closure of the electrical audit blockers, CAD/ERC/DRC review, BOM/CPL/footprint/orientation validation, and fresh exports.
