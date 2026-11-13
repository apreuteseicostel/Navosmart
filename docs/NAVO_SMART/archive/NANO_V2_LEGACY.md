# NAVO SMART V2 Nano — arhivă istorică (nu activă în V3)

Actualizat: 13 noiembrie 2026.

V3 RevF **nu are Arduino Nano**. Controlul se face prin Matek H743-WING V3/ArduPilot; senzorii, releele și serviciile Lua V3 se configurează separat și numai după verificarea pinilor. Nu folosiți codul Nano pentru firmware, scripturi SD, build-uri sau cablaj V3.

## Surse V2 păstrate pentru trasabilitate

- `firmware/NAVOMODEL_Arduino/` — Arduino Nano / ATmega328P, firmware V2.
- `tests/firmware/build-nano.sh` — compilarea istorică AVR, apelare manuală numai pentru restaurarea V2.
- `ardupilot/scripts/navo_nano_bridge.lua` — transportul vechi Nano ↔ H743, **nu se instalează pe cardul V3**.
- `tests/firmware/nano-bridge.lua` — teste de protocol V2.
- `docs/NAVO_SMART/FIRMWARE_NANO.md`, `docs/NAVO_SMART/PCB_NAVO_SMART_V2_E1.md` — schemă și protocol istorice.

Aceste fișiere rămân fizic la căile originale, pentru a nu rupe referințele și reproducerea versiunii V2. Sunt **arhivate logic**, excluse din procesul normal V3 de compilare și publicare. Nu există artifact Nano în workflow-ul V3 după integrarea PR-ului în `main`.

Pentru implementarea activă, consultați `ardupilot/NAVO_V3_SERVICE.md`, `ardupilot/scripts/navo_v3_service.lua`, `docs/NAVO_SMART/V3_NO_NANO_MIGRATION.md` și configurația master H743/G20.
