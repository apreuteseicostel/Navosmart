# NAVO SMART — WS2811 fizic pe H743-WING V3, pad **LED**

## Confirmare utilizator, 15 noiembrie 2026

- LED fizic: **WS2811, alimentat la 5 V, 3 fire** (GND, +5 V, DATA).
- Firul DATA este conectat la padul **LED** al controlerului Matek H743-Wing V3.
- Padul LED corespunde **PWM13/SERVO13** (nu ieșirea S12 și nici LED-urile interne de stare ale autopilotului).
- Placa NAVO V3 Rev F: J7 RGB-IN GND / +5 V / DATA 3,3 V; J8 RGB-OUT GND / +5 V / DATA după buffer. Traseul efectiv prin PCB și alimentarea sub sarcină trebuie verificate.

## Configurare pe H743

**Configurație nouă exclusiv pentru RGB:**
- `ardupilot/scripts/navo_rgb_service.lua` — scriptul care **trimite date WS2811 către LED-ul fizic**.
- `ardupilot/modules/navo_rgb_config.lua` — `enabled=true`, `output=13`, `count=1`, `order="GRB"`, luminozitate maxim 30 %.
- `ardupilot/modules/navo_rgb_core.lua` — culorile și prioritatea evenimentelor.

**Instalare pe SD (APM/scripts):**
1. Copiază scriptul principal în `APM/scripts/` și cele două module în `APM/scripts/modules/`.
2. În configurația ArduPilot verifică ieșirea fizică **LED/PWM13**, apoi setează **`SERVO13_FUNCTION=94`** (ScriptOut1). Implicit producătorul poate folosi `SERVO13_FUNCTION=120` pentru NeoPixel controlat de notificările ArduPilot; acesta nu se poate folosi concomitent pentru acest script.
3. Verifică `SCR_ENABLE=1`, restart, iar în Messages caută `NAVO RGB: ...`; verifică obligatoriu ordinea fizică a culorilor. Dacă LED-ul alb/verde nu afișează corect, se ajustează `order` după test.
4. LED-ul WS2811 se alimentează **din 5 V**, cu masă comună și DATA din LED/H743 (sau prin bufferul din PCB V3). Nu alimenta WS2811 din 12 V și nu folosi ieșirea GPIO direct ca alimentare.
5. **Nu activa** simultan `cfg.rgb` din `navo_v3_config.lua`, pentru că ar crea doi controlori serialLED pentru același pixel. Serviciul principal V3 poate rămâne `enabled=false` până la verificarea cuvelor/senzorilor: acest serviciu RGB este **independent și activat deja**.
6. Serviciul RGB refuză explicit ieșirea dacă `SERVO13_FUNCTION` nu este 94; **nu schimbă automat parametrii autopilotului** și nu activează alte ieșiri.

## Prioritatea culorilor

| Eveniment | Culoare fizică |
| --- | --- |
| **Apă în cocă confirmată** sau **SHT31 temperatură ≥45 °C** | ROȘU, prioritate maximă |
| Eroare de senzor de apă / SHT31 | MOV |
| Cuva/cuve în mișcare (telemetrie V3 sau PWM verificat S9/S10) | ALBASTRU |
| Far ON (Relay1/L2 G20) | ALB |
| Poziții ON (Relay2/R2 G20) | TURCOAZ |
| Far + poziții ON | GALBEN |
| Senzor apă + temperatură valide, fără alarmă și fără acțiuni | VERDE |
| Senzorii nu sunt ambii confirmați | PORTOCALIU (nu declarăm fals „normal”) |

LED-ul **nu măsoară curentul prin far**, ci citește starea logică ArduPilot Relay1/2. Dacă firmware-ul nu expune `relay:get` sau releele nu sunt active, nu va putea reflecta far/poziții până la verificarea firmware-ului. Cuvele sunt urmărite prin `NVLR_HOP` transmis de serviciul de cuve configurat sau prin PWM pentru ieșirile configurate `SERVO9/10_FUNCTION=135`; acestea indică o comandă PWM, **nu contact de limită fizic**.

### Alarme din serviciile de senzori

- `navo_water_service.lua` publică starea calibrată a apei în parametrii Lua **RAM-only** `NVLR_WST/NVLR_WET/NVLR_WMS`.
- `navo_sht31_service.lua` publică starea temperaturii și valorile SHT31 în `NVLR_TS/NVLR_TV/NVLR_TMS`.
- `navo_v3_service.lua`, dacă are cuve verificate și a fost activat separat, publică `NVLR_HOP/NVLR_HMS`.
- RGB controlează un singur pixel, limitează luminozitatea și verifică vechimea fluxurilor. Nu scrie EEPROM/flash repetat, nu comandă relays, servouri, moduri sau GPIO.
- La inițializare, **portocaliu** nu înseamnă senzor bun. Roșu pentru apă funcționează numai dacă sonda este validată și calibrată; fără servicii senzor active nu există avertizare sigură.
- Un LED RGB singur nu înlocuiește protecția de siguranță a bărcii; o eroare de alimentare/CPU poate stinge LED-ul. Verifică notificările software și ecranele de diagnostic în paralel.

### Test fără motor / siguranță

Fă testele cu ESC/motorul decuplate de la alimentare. Verifică GND, +5 V (cu multimetrul, sub sarcină), continuitatea firului de date, polaritatea J7/J8 și tensiunea de semnal a bufferului. Testează fiecare culoare, butoanele L2/R2, apoi cuvele într-un montaj liber, apoi senzorii SHT31 și apă (uscat, umed și invalid).

**Nu modifica** `RC7_OPTION`, `RC16_OPTION`, `RELAY1/2_PIN`, `SERVO9/10_FUNCTION`, motorul/cârma sau alte servo ieșiri pentru a activa LED-ul.

Surse tehnice:
- https://docs.ardupilot.org/plane/docs/common-matekh743-wing.html
- https://ardupilot.org/plane/docs/common-lua-scripts.html
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_Scripting/examples/LED_poslight.lua
