# NAVO SMART V3 — CONFIGURAȚIE MASTER G20 / GR01 / H743

**Actualizat:** 13 noiembrie 2026  
**Sursă canonică:** acest document — pentru alocări RC, relay, pini, conexiuni și autoritatea comenzilor.  
**Platformă:** barcă NAVO SMART V3, Matek H743-Wing V3, ArduPilot Rover, Skydroid G20 + GR01.  
**Important:** registru de proiect, **NU** fișier `.param` gata de import și **NU** înlocuiește testele fizice.

> Pentru orice discuție ulterioară despre butoane, lumini, canale, pini H743, Stealth sau Lua, verifică **mai întâi acest fișier**. Actualizările se adaugă aici, cu dată și dovada verificării; documentele vechi rămân păstrate, dar nu sunt autoritatea finală.

## 1. Cum citim starea informațiilor

- **Confirmare de utilizator (C):** au fost raportate două butoane fizice G20, două canale pentru luminile care funcționează; CH5 a fost testat pentru moduri. Aceasta nu este o măsurare făcută de CI.
- **Configurație raportată (R):** valori și alocări reținute din discuții și PR #73. **Nu există în repository un export `.param` real al bărcii care să confirme numeric toate aceste valori.** Reconfirmă înainte de modificări.
- **Implicit în cod (D):** preset software; nu dovedește cum e configurată telecomanda sau H743 în prezent.
- **Planificat / de verificat (P):** propunere de cablaj sau parametru; **nu** se aplică automat.
- **PR (în analiză):** cod pregătit în GitHub, dar încă neintegrat în `main` și nevalidat fizic.

**Regula principală:** nu confunda `RC CHx` (canal radio), `Sx / SERVOx` (ieșire H743), `GPIO` (identificator intern), `RELAYx` (funcție ArduPilot) și `SERIALx` (port ArduPilot).

## 2. Iluminare: autoritatea unică și cele două butoane G20

Utilizatorul a confirmat că luminile sunt deja comandate de **două butoane G20 pe două canale**. Alocările numerice de mai jos sunt configurația raportată în discuția de integrare; comparați-le cu exportul real de parametri la prima verificare.

| Funcție | Buton / RC | ArduPilot (raportat) | Ieșire H743 / PCB V3 (raportat) | Autoritate |
|---|---|---|---|---|
| Far ON/OFF | **L2 / CH7** | `RC7_OPTION=28` → **Relay 1**; `RELAY1_FUNCTION=1` | **S6 / GPIO55** → **J5 FAR-CTL** | **ArduPilot Relay** |
| Poziții ON/OFF | **R2 / CH16** | `RC16_OPTION=34` → **Relay 2**; `RELAY2_FUNCTION=1` | **S7 / GPIO56** → **J6 POS-CTL** | **ArduPilot Relay** |

Setări asociate consemnate: `SERVO6_FUNCTION=-1` și `SERVO7_FUNCTION=-1`. **Nu le importa orbește:** verifică întâi `RC7_OPTION`, `RC16_OPTION`, `RELAY1_FUNCTION`, `RELAY2_FUNCTION`, pinii configurați efectiv ai releelor, SERVO6/7 și dacă există alte funcții alocate.

**Regula de funcționare:** butoanele fizice L2/R2 trebuie să comute luminile direct din G20 → GR01 → H743, **chiar dacă aplicația Android este închisă**. Aplicația nu trimite un al doilea `toggle` la interpretarea acelorași impulsuri RC. Ieșirile GPIO55 și GPIO56 nu trebuie controlate simultan și de Lua.

**Stealth (PR #73, draft):** folosește același controler nativ ArduPilot, prin `MAV_CMD_DO_SET_RELAY (181)` — la activare solicită **Relay 2 poziții ON** (index MAVLink 1, valoare 1), apoi **Relay 1 far OFF** (index MAVLink 0, valoare 0). În aplicație, controlul manual poate folosi valoarea 2 pentru comutare, dar **nu** ca reacție suplimentară la un buton RC deja procesat de ArduPilot.

- Nu se cere `NV3VER` / `NV3CAP` pentru a comanda aceste relee fizice.
- Fără feedback confirmat despre becuri/relee, UI spune „**comandă solicitată, neconfirmată**”, nu „stare fizică confirmată”.
- Stealth **nu** reaplică automat comenzile după o intervenție fizică RC; utilizatorul poate reaplica explicit.
- La ieșirea din Stealth nu restaurează presupusa stare inițială a farului când nu avem feedback real.
- Controlul automat al pozițiilor nu trebuie să preia implicit autoritatea de la R2 la pornire; în PR #73 modul implicit este `RC`, iar `AUTO` se selectează explicit în sesiune.
- **Nu** aloca `lights={head_gpio=55,position_gpio=56}` în configurația Lua V3 pentru această barcă. Păstrează `lights=nil`.

**Conflict istoric rezolvat în planificare:** presetul software vechi `custom/G20_INTEGRATION.md` și `NavoG20Controller.qml` conținea `R2/CH16 = SONAR`, pe când configurația fizică de iluminare raportată acum îl folosește pentru poziții. Nu reactiva automat acțiunea SONAR pe R2; păstrează funcția sonar pe un alt control explicit, după verificare.

## 3. G20 / GR01 — canale RC și moduri

### Comutator CH5 — moduri native H743

Ultimul test raportat: **jos MANUAL / mijloc AUTO / sus GUIDED**, prin **CH5**, fără animație artificială în aplicație. Fișierul existent de referință este [`ardupilot/params/navo_ch5_manual_auto_guided.param`](../../ardupilot/params/navo_ch5_manual_auto_guided.param).

```ini
MODE_CH 5
MODE1 0
MODE2 0
MODE3 10
MODE4 10
MODE5 15
MODE6 15
RC5_OPTION 0
```

Atenție: valorile sunt presetul **din repository**, nu dovada unui import pe H743. Verifică intervalele PWM CH5 și modul raportat de autopilot. Modurile MANUAL/HOLD/RTL și controlul motorului sunt autoritatea H743, nu a unui listener RC Android.

### Restul controalelor

Tabelul următor combină presetul fotografiat G20 și starea funcțională discutată ulterior. Intrările fără verificare sunt doar implicite în aplicație.

| Canal | Control G20 | Funcție / observații | Stare |
|---|---|---|---|
| CH1–CH4 | Stick-uri | Propulsie/cârmă: axele exacte și sensurile trebuie confirmate | P |
| CH5 | Comutator 3 poziții | MANUAL / AUTO / GUIDED | C + preset în repo |
| CH6 | H / HOME | RTL / confirmare; în codul NAVO long-press 1800 ms | D, hardware de testat |
| CH7 | L2 | **Far / Relay 1** | C/R |
| CH8 | CAMERA | Cameră / fullscreen în presetul aplicației | D |
| CH9 | B1 | Nicio acțiune NAVO implicită | D |
| CH10 | B2 | Nicio acțiune NAVO implicită | D |
| CH11 | L1 | Cuva stângă; long-press 1500 ms în listenerul NAVO | D, de verificat |
| CH12 | PUMP | Etichetă din preset; nicio pompă confirmată | D |
| CH13 | STOP / PAUSE | HOLD în aplicație | D |
| CH14 | X3 | Fără funcție implicită | D |
| CH15 | R1 | Cuva dreaptă; long-press 1500 ms în NAVO | D, de verificat |
| CH16 | R2 | **Poziții / Relay 2**; presetul vechi de aplicație folosea SONAR | C/R; conflict istoric |

În cod, `hardwareActionsEnabled=false` este valoarea implicită pentru listenerul opțional de butoane G20. Monitorul canalelor funcționează separat. Listenerul trebuie să evite dublarea funcțiilor pe care `RCx_OPTION` le execută deja nativ pe H743. Nu confunda acțiunea presetată în UI cu starea reală a sistemului radio.

## 4. H743 + PCB V3 RevF — alocări și protecții

| Funcție | H743 / PCB V3 | Stare |
|---|---|---|
| Far | S6/GPIO55 raportat → PCB **J5 FAR-CTL**; sarcina farului la **J2 FAR** | R, verifică legătura și releul |
| Poziții | S7/GPIO56 raportat → PCB **J6 POS-CTL**; sarcina la **J4 POS12** | R |
| Baterie 4S | J1 BAT4S, maxim **16,8 V** | Documentație PCB; verifică distribuția |
| Poziții 12 V | UBEC12 / J3, J4 ieșire protejată | Documentație PCB |
| RGB | PCB J7 date + alimentare externă 5 V, J8 LED | P, nevalidat |
| NTC baterie | J9 NTC → J10 ieșire analogică către ADC H743 | P, necesită calibrare |
| Apă în cocă | J11 electrozi → J12 excitație GPIO + ADC H743 | P, calibrare înainte de activare |
| Cuve | Ieșiri software implicite **S9 / S10**; închis 1500 µs, deschis 1900 µs, ciclu 900 ms | D, **nu** calibrare mecanică |
| ESC / cârmă | Controlate de H743, nu prin Nano | Arhitectură; ieșirile reale de confirmat |

**Alimentare:** semnalele analogice/GPIO H743 sunt 3,3 V; **J7 trebuie alimentat cu 5 V** inclusiv pentru driverul de poartă al MOSFET-urilor. GND comun, fără legarea în paralel a ieșirilor pozitive ale BEC-urilor. Nu scurtcircuita ieșirea negativă comutată a farului/pozițiilor la GND.

## 5. Conectivitate, GNSS, LAN — rezumat din schema veche R1

Acestea sunt **mapări planificate sau folosite în teste**, nu declarații că firele au fost toate măsurate:

| Dispozitiv | Legătură / configurare de referință | Stare |
|---|---|---|
| GR01 SBUS | GR01 SBUS → **H743 RX6**, GND comun | Schema R1; verifică semnalul |
| GR01 MAVLink | GR01 RX → **H743 TX7**; GR01 TX → **H743 RX7**; GND comun; UART7/SERIAL1 în schema R1 | R/P, verifică portul real |
| UM982 dual GNSS | UM982 RX1 → **H743 TX2**, TX1 → **H743 RX2**, GND comun; UART2 fizic / SERIAL3 ArduPilot | R/P |
| UM982 parametri de referință | `SERIAL3_PROTOCOL=5` (GPS), `GPS1_TYPE=25`, baud 115200; heading dual-antena | P, teste H743/firmware |
| UM982 busolă IST8310 | SDA/SCL → H743 DA1/CL1; 3,3 V logic; alimentare modul GNSS din 5 V extern compatibil | P |
| USR-TCP232-ED2 | UART0 pentru sonar serial: RXD0 pin7, TXD0 pin6; legătura prin switch Ethernet | Schema R1; validare |
| GR01 / sonar / cameră | Subnet operațional discutat `192.168.144.x`; Kogger `192.168.144.7` | R |
| Cameră IP | Valoare observată anterior la reset `192.168.0.64`; preset aplicație `192.168.144.64:554` (RTSP) | Nu confunda IP din fabrică cu cel configurat |
| ED2 | `192.168.144.30` apare ca **exemplu de proiect** în schema veche | P; nu presupune IP actual |

Teste UM982 în interior: poate exista poziție GPS fără heading valid; `INSUFFICIENT_OBS` și yaw invalid nu demonstrează defect hardware. Fallback-ul de orientare la H743 nu este echivalent cu heading-ul dual-antenă valid.

## 6. Lua V3 — ce păstrăm și ce NU duplicăm

- **Luminile:** control unic **ArduPilot Relay nativ**. Pentru această barcă, `ardupilot/modules/navo_v3_config.lua` păstrează `lights=nil`; scriptul `navo_v3_service.lua` nu deține GPIO55/56. Nu reinstala bridge-ul Nano V2 pentru lumini.
- **Cuve / alte funcții V3:** serviciul `navo_v3_service.lua` și `navo_v3_core.lua` există, dar trebuie activate individual numai după verificarea ieșirilor, PWM și parametrilor reali. `enabled=false` este configurația implicită livrată în repository.
- **SHT31 temperatură/umiditate interioară:** serviciu independent de **citire**, nu controler de lumini; modificările de decuplare sunt în [PR #70](https://github.com/apreuteseicostel/Navosmart/pull/70) (în analiza integrării). Testare firmware și I2C necesară.
- **Apă V3:** serviciu de diagnoză separat, în [PR #72](https://github.com/apreuteseicostel/Navosmart/pull/72); rămâne dezactivat/necalibrat până la verificarea PCB și sondei.
- **Stealth / integritatea rutării releelor:** [PR #73](https://github.com/apreuteseicostel/Navosmart/pull/73) — **draft, neintegrat în `main` la data acestui document**. Aici se corectează comanda de lumini, dublarea acțiunilor L2/R2 și controlul AUTO al pozițiilor.

**Nu ștergem scripturile vechi** doar pentru că au nume similare: arhiva Nano V2 este istorică, SHT31/apă sunt independente, iar serviciul V3 are și alte funcții în afară de iluminare. Eliminăm **autoritatea dublă pe ieșirile de lumini**, nu tot codul auxiliarelor.

## 7. Ce lipsește pentru statut „hardware verificat”

1. Salvează un export real de parametri H743 `.param` (firmware/version + `MODE_CH`/`MODE1..6`, `RC5/7/16_OPTION`, `RELAYx_*`, `SERVO6/7/9/10_*`, `SERIALx_*`, GPS).
2. Confirmă în Mission Planner/QGroundControl **CH7, CH16, CH5** și numerele de ieșire GPIO/Relay reale. Nu rescrie setările existente doar pentru a le potrivi tabelului.
3. Testează L2/R2 cu aplicația închisă și deschisă; cu listenerul Android dezactivat/activat; fiecare apăsare trebuie să comute o singură dată.
4. În PR #73, testează Stealth: solicită poziții ON, apoi far OFF; fără al doilea controller Lua; intervenție RC prioritară, fără restabilire automată.
5. Verifică polaritatea și alimentarea 5 V a driverului din PCB, apoi testează far/poziții fără risc de scurt.
6. Testează separat GR01 MAVLink, UM982 heading dual, cuvele (fără sarcină), senzorii, LAN/sonarul și fail-safe. **CI verde ≠ barcă validată.**
7. Notează aici data, revizia firmware, valorile măsurate și rezultatul. Doar atunci schimbă statutul din R/P în C hardware.

## 8. Documentele vechi păstrate și sursele de adevăr

- [Registru vechi de pini / RC, 15 oct. 2026](../NAVO_V3_PINI_H743_G20_GR01.md) — istoric; include R2=SONAR și CH5 încă neconfirmat la acea dată.
- [Schema de conexiuni R1 și albumul de bază](../hardware/2026-10-15/Schema_conexiuni_R1.md) — fire, contacte, LAN, alimentări; cu verificări fizice restante.
- [Presetul inițial G20](../../custom/G20_INTEGRATION.md) — este fotografia stării vechi, **nu** configurație finală a luminilor.
- [Parametri CH5 de referință](../../ardupilot/params/navo_ch5_manual_auto_guided.param).
- [PCB RevF, tensiuni și J1–J12](PCB_NAVO_SMART_V3_REVF.md).
- [Stealth în main (precedent)](STEALTH_PROFILE.md) și [PR #73 (modificări propuse)](https://github.com/apreuteseicostel/Navosmart/pull/73).
- [Contract / Lua V3](../../ardupilot/NAVO_V3_SERVICE.md); [SHT31](SHT31_INTERIOR.md).
- [Setările Android G20 din cod](../../custom/qml/NavoG20Controller.qml); [Dashboard](../../custom/qml/NavoDashboard.qml).

## 9. Diagnostic Stealth — două comenzi Relay consecutive (13 nov. 2026)

**Simptom observat pe G20:** când se activează Stealth, luminile de poziție se
aprind, dar farul rămâne pornit și QGroundControl afișează
`Unable to send command: Waiting on previous response to same command.`

**Cauză identificată în cod:** Stealth trimitea Relay 2 ON și Relay 1 OFF aproape
simultan, ca două `MAV_CMD_DO_SET_RELAY (181)`. QGroundControl v5.0.7
permite o singură comandă de același tip în așteptarea ACK-ului pentru aceeași
componentă, indiferent de indexul releului. A doua era refuzată.

**Corecția codului (PR #73):** trimitere secvențială cu
`Vehicle.mavCommandResult`: se solicită pozițiile ON, se așteaptă
`COMMAND_ACK` final acceptat (MAV_RESULT_ACCEPTED=0, failureCode=0),
**abia apoi** se solicită farul OFF. Se așteaptă ACK separat pentru far.
La refuz/timeout nu se retrimite automat și nu se pretinde iluminare confirmată
fizic. Timpul-limită este 12 s pe pas; interfața arată progresul.
Controalele RC fizice CH7/CH16 nu se modifică, iar `lights=nil` rămâne
valabil pentru scriptul Lua pe GPIO55/56.

**Dovadă:** fotografia G20 trimisă în conversația NAVOMODEL din 13 nov. 2026,
21:04 UTC. **Stare:** remediere software în PR #73; testele GitHub și acceptanța
finală pe G20 trebuie urmărite pe commitul final, nu pe un APK anterior.

## 10. Jurnal de actualizări

- **2026-10-15:** registrul original H743/G20/GR01 și schema R1; mapări proiectate.
- **2026-10-28:** în discuții s-a confirmat folosirea CH5 pentru comutatorul MANUAL/AUTO/GUIDED.
- **2026-11-13:** utilizatorul a reconfirmat două butoane / două canale de iluminare; corecție de arhitectură Stealth spre releele ArduPilot existente; PR #73 în review. Valorile numerice sunt **de reconfirmat prin exportul real H743**, nu se inventează o fotografie de parametri.
- **2026-11-13, 21:04 UTC:** fotografie G20: poziții ON, far rămas ON, eroare QGC din cauza a două comenzi MAV_CMD 181 simultane. Corecție secvențiere ACK în PR #73, verificare în curs.

---
**Regulă de întreținere:** actualizează întâi acest document la fiecare schimbare de cablaj, RC, GPIO, Lua, MAVLink ori subnet; păstrează legături către commit/PR și rezultatul testului. Nu modifica simultan două surse hardware pentru aceeași ieșire.
