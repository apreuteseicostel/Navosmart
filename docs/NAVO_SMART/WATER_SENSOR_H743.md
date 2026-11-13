# NAVO SMART V3 RevF — sondă apă J11/J12, serviciu Lua separat (bench-only)

Status: **cod de diagnostic pregătit, NU comisionat/validat electric**. Nu modifica servo/motor/cuve și nu activa RTL automat. Înainte de folosire, confirmă cablarea fizică, nivelurile și parametrii actuali H743. Source: `NAVO_SMART_V3_RevF_Ghid_Conexiuni_J1-J12.docx` (Library /NAVOMODEL, 8 Nov 2026); firmware Rover 4.7.2 MatekH743 hwdef.

## Conectori (pinul 1 se verifică pe silkscreen/pad pătrat, NU după culori)
| Placă V3 | Pin | Net | Funcție |
|---|---|---|---|
| J11 WATER | 1 | WATER_DRIVE | Electrod 1 |
| J11 WATER | 2 | WATER_RETURN | Electrod 2 |
| J12 WATER_H743 | 1 | GND | Masă H743 comună |
| J12 WATER_H743 | 2 | WATER_EXC | Comandă digitală EXC (propunere S8/PD13, GPIO57) |
| J12 WATER_H743 | 3 | WATER_OUT | Semnal analogic (propunere CU2/PA7, ADC7) |

J11 nu furnizează direct telemetrie. J12 trebuie cablat 3 fire către H743. Nu conecta la +5 V sau Vx servo: **J12.2 este 3.3 V logic pulsat**, iar J12.3 trebuie să rămână între 0 și 3.3 V. Nu alimenta placa V3 prin pinul analogic. Verifică și alimentarea 3.3 V a condiționării senzorului din J10.2, masele comune și rezistorul EOL 1 MΩ al sondei, conform asamblării reale.

## Conflicte care trebuie rezolvate ÎNAINTE de activare
- ArduPilot `MatekH743` definește S8 = PD13 = GPIO57 și CU2/PA7 = ADC7.
- `SERVO8_FUNCTION=-1` transformă ieșirea S8 în GPIO. **Nu modifica** până nu verifici că S8 nu este folosită de motor, cârmă, cuve, RC sau altă funcție.
- `BATT2_MONITOR=0` este necesar pentru a folosi ADC7 în acest serviciu, deoarece `BATT2_CURR_PIN=7` poate folosi CU2. **Nu dezactiva BATT2** dacă măsori realmente o a doua baterie.
- Conflictele cu `RELAYx_PIN`, alte scripturi Lua și alți utilizatori ai S8/ADC7 trebuie verificate din parametrii salvați. Nu folosi simultan `navo_v3_service.lua` cu `water` configurat și serviciul separat: un singur proprietar al sondei.
- `SCR_ENABLE=1` este deja confirmat pentru Rover. Niciunul dintre scripturile de aici nu schimbă automat parametri ArduPilot.

## Fișiere instalate cu Mission Planner MAVFTP
1. `ardupilot/scripts/navo_water_service.lua` → `APM/scripts/navo_water_service.lua`
2. `ardupilot/modules/navo_water_core.lua` → `APM/scripts/modules/navo_water_core.lua`
3. `ardupilot/modules/navo_water_config.lua` → `APM/scripts/modules/navo_water_config.lua`

`navo_water_config.lua` are inițial `enabled=false`, `calibrated=false`. După măsurarea cablajului și verificarea `SERVO8_FUNCTION` și `BATT2_MONITOR`, schimbă **numai** `enabled=true`. Scriptul va furniza `NV3WADC` (tensiune reală) și `NV3WSTAT=5` (necalibrat). Va pulsa doar EXC pentru 120 ms și o va opri după citire. **Nu va publica niciodată USCAT/UD ca valoare validă** în acest mod.

## Calibrare fizică, cu motorul/ESC-ul fără posibilitate de pornire
1. Multimetru cu placa nealimentată: verifică J12.1=GND, J12.2→S8, J12.3→CU2, polaritatea și lipsa scurtului. Confirmă că J10.2 are referință de 3.3 V când alimentarea este pornită și că J12.3 nu depășește 3.3 V.
2. Sonda complet uscată: observă `NV3WADC` (V) pe G20 sau în MAVLink, notează mai multe valori.
3. Umezește **numai electrozii separați**, departe de PCB/H743 și cu alimentarea adecvat protejată, apoi notează tensiunea.
4. Cu alimentarea oprită între schimbări de cablu, testează electrod/senzor întrerupt și scurt doar în condiții sigure de banc, apoi măsoară tensiunile.
5. Numai după ce valorile sunt clar separate, introduce `valid_min_v`, `valid_max_v`, `threshold_v`, `wet_above` și setează `calibrated=true`. Aceste valori NU sunt oferite de documentele de proiect și nu pot fi inventate.
6. Repornește H743 și confirmă 3 citiri consecutive pentru fiecare stare. Verifică pierdere MAVLink, reboot, deconectarea sondei și condițiile umede; niciodată fără propulsia dezactivată la test.

## Contract MAVLink read-only (autopilot component 1)
| Mesaj NAMED_VALUE_FLOAT | Utilizare |
|---|---|
| `NV3WADC` | Voltaj brut la intrarea analogică (V), diagnostic pentru calibrare |
| `NV3WSTAT` | 1 așteptare/confirmare; 2 citiri valide calibrate; 3 citire sau domeniu defect; 4 conflict config/firmware; 5 necalibrat |
| `NV3WATER` | 0 uscat / 1 ud; publicat doar la 3 probe valide consecvente și calibrare activă |
| `NV3WFAULT` | 0 fără defect / 1 defect; nu înseamnă că lipsa sondei este o stare uscată |

Aplicația G20 actualizată trebuie să arate `NV3WADC` în **Cuve & siguranță hardware**, să primească `NV3WSTAT` separat de heartbeat-ul serviciului V3 pentru cuve/lumini și să afișeze `—` până la calibrare. Pe durata punerii în funcțiune, **alertele sunt numai informative; nu se trimit comenzi automate RTL/HOLD** din lectura senzorului de apă. Decizia de navigație trebuie implementată/verificată ulterior la bord, nu doar în Android.

## CI și acceptare
`lua5.3 tests/firmware/water-only.lua` testează logica și adaptorul cu dispozitive simulate. Testele QML/C++ verifică sursa MAVLink, validarea, expirația și interblocarea comenzilor de siguranță. CI nu validează instalația fizică. Nu integra în main/nu lansa APK de producție până când bench testul și verificarea S8/CU2 nu sunt complete.
