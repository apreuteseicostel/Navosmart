# NAVO V3 — mutarea sondei de apă de pe CU2 pe AirS (16 noiembrie 2026)

**Stare: pregătire software în PR Draft. Nu s-a schimbat nicio conexiune fizică și niciun parametru pe H743.**
Motiv: CU2 / PA7 / analog pin 7 trebuie eliberat pentru un senzor extern de curent total al bateriei 4S; sonda de apă J11/J12 folosește azi CU2.

## Dovada conexiunii vechi
- PCB V3 RevF: J11 WATER este perechea de electrozi; J12.1 GND, J12.2 WATER_EXC -> S8 / GPIO57, J12.3 WATER_OUT -> CU2 / PA7 / ADC7.
- În `2026-11-13 19-37-04.tlog`, sondei i s-au măsurat aproximativ 0.002 V uscat și 1.88 V ud (prin `NV3WADC`). Conexiunea analogică a funcționat atunci; nu certifică calibrarea open/short sau starea curentă.
- NTC-ul bateriei este propus pe RSSI / PC5 / ADC8; **nu lua RSSI**, pentru a nu bloca temperatura.
- Padul alternativ `AirS` este **PC4 / ADC4** în `MatekH743`, cu divizor 1:1 încorporat, admis până la 6.6 V la intrarea padului. **J12.3 rămâne limitat la 0..3.3 V de PCB-ul RevF**, iar firmware-ul ArduPilot `SCALE(2)` reconstituie nominal tensiunea de la pad în `analog:channel():voltage_latest()`. Divizorul reduce rezoluția intrării pe ADC; trebuie verificat dacă limitele uscat/ud și detectarea erorilor rămân suficient separate.

## Wiring migration — numai fără tensiune și motor nealimentat

| Funcție | Înainte | După |
|---|---|---|
| J12.1 GND | GND H743 | **Neschimbat** |
| J12.2 WATER_EXC | S8 / GPIO57 | **Neschimbat** |
| J12.3 WATER_OUT | CU2 / PA7 / ADC7 | **AirS / PC4 / ADC4** |
| NTC J10.3 | RSSI / PC5 / ADC8 (conform planului) | **Neschimbat** |
| Senzor curent total extern (doar ieșire analogică!) | Neinstalat | **CU2 / PA7 / ADC7** |
| Senzor extern de curent: alimentare/șunt | Neinstalat | Conform fișei senzorului și distribuitorului bateriei; nu pe CU2 |

1. Cu bateria fizic scoasă, verifică prin continuitate firele J12.1/2/3. **Scoate numai firul J12.3 din CU2 și du-l la padul AirS**. Nu lega analogicul în paralel pe AirS și CU2.
2. Confirmă că AirS nu are deja senzor analog de viteză aer și că niciun alt script/monitor nu citește ADC4. Dacă există un proprietar AirS, nu efectua migrarea: alege ADC extern I2C compatibil sau alt plan validat.
3. Cu doar sursa de joasă putere, motor/ESC izolat, verifică J12.3: 0..3.3 V față de GND în orice stare; asigură-te că nu există alimentare spre input în absența H743.
4. **Mai întâi înregistrează backup** pentru `APM/scripts/modules/navo_water_config.lua`, `.param`, scripturile actuale; nu suprascrie configurațiile de calibrare personale. Folosește versiunea PR a `navo_water_service.lua`.
5. Abia după cablare, în `APM/scripts/modules/navo_water_config.lua`: `adc_pin=4`, `airs_wiring_verified=true`, `calibrated=false`; `enabled=true` doar pentru **diagnostic** dacă `SERVO8_FUNCTION=-1`, cablajul și alimentările au fost verificate. `ARSPD_TYPE`, dacă există, trebuie 0; `BATT_MONITOR/BATT_CURR_PIN` și `BATT2_MONITOR/BATT2_CURR_PIN` nu trebuie să dețină ADC4. Modificarea codului **nu schimbă singură cablajul sau parametrii**.
6. Citește `NV3WADC`: uscat, ud, cablu întrerupt, scurt controlat. După măsurarea noilor domenii poți configura din nou pragurile și `calibrated=true` numai dacă și open/short au un diagnostic distinct. Până atunci, indicatorul trebuie să rămână necalibrat, fără comandă RTL/HOLD automată.
7. Verifică `NV3WSTAT`, `NV3WDET`, `NV3WFLT` și că LED-ul de alarmă nu primește stări vechi drept confirmări. `NV3WADC` reconstituit trebuie comparat cu un multimetru la AirS.

## Senzorul total al bateriei 4S: aceeași baterie, nu două

**Opțiunea preferată după măsurători:** folosește monitorul bateriei 1 pentru voltajul existent și curentul nou, nu două monitoare care măsoară același pack:

- `BATT_MONITOR=4` (analog voltage/current);
- `BATT_VOLT_PIN=10` — păstrează tensiunea principală deja corectă;
- `BATT_CURR_PIN=7` — înlocuiește intrarea curentului intern `11` cu CU2 (senzor extern);
- `BATT_AMP_PERVLT` și `BATT_AMP_OFFSET` — **calibrare conform senzorului extern și ampermetrului**, nu valorile Matek `40`/`66.7` ale șuntului integrat;
- `BATT2_MONITOR=0` dacă nu există monitor de baterie 2 independent; `BATT2_CURR_PIN` nu contează când monitorul 2 este inactiv, dar nu-l folosi simultan cu alt serviciu.

**Nu aplica automat acești parametri.** Verifică exportul real `.param` și instalarea înainte de orice `BATT_CURR_PIN`. Nu conecta ieșirea de curent brut a unui șunt direct la CU2: semnalul trebuie condiționat de un modul electronic de măsurare compatibil **0–3.3 V la ECU**, cu masă de referință sigură și izolare adecvată. Amplasează partea de putere a senzorului dimensionat pentru curentul maxim înainte de **toate** ramurile: ESC, PCB far, BEC 12 V, BEC 5 V și orice alt consumator. Evită să treci 50 A prin trasee subdimensionate, multimetrul neprotejat sau intrări ale H743.

Cu `BATT_CURR_PIN=7`, H743 înlocuiește senzorul onboard pentru curentul bateriei 1. Asta face ca `vehicle.batteries.get(0).current` din NAVO SMART să folosească potențial valoarea curentului total calibrat. Fără cablajul și calibrarea corecte, UI nu poate „repara” consumul prin adunare.

## Rollback

Cu alimentarea oprită, scoate senzorul de curent de pe CU2, mută J12.3 AirS -> CU2, restabilește `BATT_CURR_PIN=11` numai dacă acesta era cu adevărat parametrul original salvat și readu `adc_pin=7` din backup. Nu restabili orbesc praguri vechi.

## Dovezi și surse
- `docs/NAVO_SMART/WATER_SENSOR_H743.md`, `ardupilot/scripts/navo_water_service.lua`, `ardupilot/modules/navo_water_config.lua`.
- Matek V3: https://manuals.plus/ae/1005008223045803
- ArduPilot MatekH743 hwdef: https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_HAL_ChibiOS/hwdef/MatekH743/hwdef.dat
- ArduPilot analog `voltage_latest`: https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_HAL_ChibiOS/AnalogIn.cpp
- Battery monitoring: https://ardupilot.org/rover/docs/common-3dr-power-module.html
