# NAVO SMART — documentație permanentă

## Începe aici: configurația actualizată G20 / H743 / V3

**[CONFIGURAȚIE MASTER G20 / GR01 / H743 — 13 noiembrie 2026](CONFIGURATIE_MASTER_G20_H743_V3.md)** — punctul central pentru alocările fizice și RC, Relay1/2 pentru lumini, comutatorul CH5, Stealth, Lua V3, GNSS și LAN. Conține statutul fiecărei afirmații și trimiteri la registrul vechi din octombrie, schema R1 și PR-ul de corecție. **Nu utilizați documentele istorice ca valori `.param` confirmate.**

Director canonic pentru deciziile proiectului NAVO SMART.

## Ramuri tematice
- `V3_NO_NANO_MIGRATION.md` — arhitectura V3 fără Nano și statutul CI.
- `archive/NANO_V2_LEGACY.md` — index istoric V2, fără rol activ în V3.
- `PCB_NAVO_SMART_V2_E1.md` — **istoric V2**, placa, alimentări și pinout Nano.
- `FIRMWARE_NANO.md` — **istoric V2**, firmware Nano/UART, nu se compilează în CI V3.
- `H743_ARDUPILOT_UM982_GR01.md` — autopilot, GNSS, RC/MAVLink și servo/ESC.
- `APP_NAVO_SMART.md` — aplicația Android/QML.
- `SONAR_LAN_CAMERA.md` — Ethernet, Kogger și cameră.
- `SAFETY_INTEGRATION.md` — autoritatea comenzilor și comportamentul la defect.

Regulă: H743 rămâne controlerul critic al propulsiei, cârmei și servo-urilor cuvelor. Documentele **NAVO SMART V2/Nano** sunt istorice; pentru **V3 RevF** nu mai există Arduino Nano pe placa auxiliară. Nu confundați interfața V2 cu serviciile Lua și releele native ArduPilot V3.
