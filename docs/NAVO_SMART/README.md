# NAVO SMART — documentație permanentă

Director canonic pentru deciziile proiectului NAVO SMART.

## Configurația V3 în lucru
- [Registrul pinilor H743 și canalelor G20/GR01](../NAVO_V3_PINI_H743_G20_GR01.md) — punctul central pentru alocări și verificări. H743 nu este încă instalat/configurat de utilizator.

## Ramuri tematice
- `PCB_NAVO_SMART_V2_E1.md` — placa, alimentări, conectori și pinout Nano.
- `FIRMWARE_NANO.md` — Arduino Nano și protocol UART.
- `H743_ARDUPILOT_UM982_GR01.md` — autopilot, GNSS, RC/MAVLink și servo/ESC.
- `APP_NAVO_SMART.md` — aplicația Android/QML.
- `SONAR_LAN_CAMERA.md` — Ethernet, Kogger și cameră.
- `SAFETY_INTEGRATION.md` — autoritatea comenzilor și comportamentul la defect.

Regulă: H743 rămâne controlerul critic al propulsiei, cârmei și servo-urilor cuvelor. Nano este auxiliar/monitorizare numai în V2; V3 elimină Nano și folosește serviciul H743.
