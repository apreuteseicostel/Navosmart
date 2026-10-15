# NAVO V3 — registru de pini H743 și canale G20 / GR01

Actualizat: 15 octombrie 2026. Document de lucru pentru stabilirea configurației, **nu instrucțiuni finale de cablare sau fișier de parametri de încărcat**.

## Situația reală

Costel a confirmat că deține Matek H743-WING V3, dar nu a instalat/configurat încă firmware-ul. Nu există un export `.param` al instalației de verificat în această etapă. Configurația se proiectează de la zero; după instalare vom salva aici și exportul verificat. Imaginile primite sunt de prezentare comercială; fotografia plăcii fizice urmează.

Inventarul de mai jos este extras din codul și documentația repository-ului, baza PR #21 `dfa5ecb1323845890828634c3d74e225a45599e5`. Nu reprezintă o citire live a G20/GR01. Nu au fost modificate setări radio, firmware sau parametri hardware pentru acest document.

## Trei numerotări distincte

- **CH1–CH16:** canalele RC transmise de G20/GR01. G20 Device Tool stabilește asocierea buton/axă → canal.
- **S1–S13 / SERVOx:** ieșiri fizice ale H743, care trebuie configurate separat. CH11 nu înseamnă obligatoriu S11.
- **GPIO / ADC / SERIALx:** identificatori firmware. Eticheta TX/RX de pe placă nu stabilește singură numărul SERIALx; nici numărul GPIO nu este numărul canalului RC.

Fluxul planificat: G20 → GR01 → intrare RC H743 → MAVLink RC_CHANNELS → monitorul NAVO. Comenzile critice trebuie să aibă un singur responsabil; evităm acționarea simultană prin opțiuni RC ArduPilot și prin acțiuni NAVO.

## Inventarul celor 16 canale RC

Etichetele tuturor canalelor provin din presetul fotografiat, consemnat anterior în `custom/G20_INTEGRATION.md`. Cele șapte canale de acțiuni sunt confirmate și în valorile implicite din `NavoG20Controller.qml`. Setările persistente ale unei aplicații deja folosite pot diferi.

| Canal | Control consemnat în preset | Acțiune implicită în NAVO | Statut / de clarificat |
|---|---|---|---|
| CH1 | Stick, grup CH1–CH4 | Fără acțiune de buton | Axă și sens neconfirmate; nu atribuim încă accelerația/cârma |
| CH2 | Stick, grup CH1–CH4 | Fără acțiune de buton | Axă și sens neconfirmate |
| CH3 | Stick, grup CH1–CH4 | Fără acțiune de buton | Axă și sens neconfirmate |
| CH4 | Stick, grup CH1–CH4 | Fără acțiune de buton | Axă și sens neconfirmate |
| CH5 | G-S | Nu este procesat de listenerul de butoane | Rolul fizic și posibila asociere cu modurile se verifică |
| CH6 | HOME / H | RTL: deschide confirmarea ACASĂ în aplicație | Apăsare lungă implicit 1800 ms; nu este RTL direct autonom în această cale |
| CH7 | L2 | Far ON/OFF | În V3, aplicația cere ON/OFF explicit serviciului H743 |
| CH8 | CAMERA | Camera față / comutare fullscreen | Acțiune UI; nu comandă alimentarea camerei |
| CH9 | B1 | Nicio acțiune implicită | Nu se declară liber doar pentru că NAVO nu îl procesează |
| CH10 | B2 | Nicio acțiune implicită | Rolul fizic de verificat |
| CH11 | L1 | Cuva stânga | Apăsare lungă implicit 1500 ms; calibrare obligatorie |
| CH12 | PUMP | Nicio acțiune implicită | Etichetă preset; nu dovedește existența unei pompe în barcă |
| CH13 | STOP / PAUSE | HOLD | În calea actuală este cerut prin aplicație |
| CH14 | X3 | Nicio acțiune implicită | Rolul fizic și pozițiile de verificat |
| CH15 | R1 | Cuva dreapta | Apăsare lungă implicit 1500 ms; calibrare obligatorie |
| CH16 | R2 | SONAR | Deschide pagina sonar; nu este implicit alternare sonar/cameră |

**Nu sunt încă alocate/confirmate:** canalul comutatorului cu trei poziții, axele exacte de conducere, zoom-ul fizic al hărții, un buton dedicat pozițiilor și unul pentru ambele cuve. Acțiunile POZITII și CUVE_AMBELE există ca opțiuni în aplicație, fără canal implicit dedicat. Metodele `modeSwitch()` și `leftStick()` există, dar nu sunt conectate de listenerul actual la un canal RC validat.

Cerința anterioară de discutat: stick dreapta pentru conducere, control stânga pentru zoom, comutator cu trei poziții pentru moduri și R2 sonar/cameră. Nu convertim această intenție în alocare numerică fără verificarea monitorului RC.

## Comportamentul actual al integrării G20

Acțiunile sunt implicit **dezactivate** (`hardwareActionsEnabled=false`), în meniul Avansat. Monitorul RC poate fi folosit pentru identificare. Pragurile actuale: valori valide 900–2100 µs, eliberat ≤1600, apăsat ≥1800; acțiuni obișnuite după 120 ms. După conectare trebuie observată poziția eliberată înainte de o acțiune. Telemetria RC expiră după 1 s, iar canalele duplicate sunt blocate. Replay și legătura inactivă blochează intrarea.

Durata apăsării L1/R1 (1500 ms) este distinctă de durata deschiderii cuvei (900 ms implicit). În V3, închiderea este temporizată în serviciul H743; aplicația așteaptă raportarea încheierii ciclului. Această migrare nu mută încă interpretarea butoanelor G20 în Lua: declanșarea prin listenerul NAVO depinde încă de aplicație. Comanda RC directă la bord rămâne de proiectat fără dublare.

## Pini și ieșiri H743 — registru de proiectare

Niciun rând de mai jos nu este confirmare de cablare. Propunerile istorice sunt păstrate pentru discuție, nu activate. Configurația Lua livrată are `enabled=false` și secțiunile hardware neatribuite.

| Funcție | Semnal / destinație | Candidat consemnat | Statut |
|---|---|---|---|
| Motor / ESC Flycolor | PWM H743 → ESC | Nespecificat | De ales; motor unic + cârmă, fără presupunere SERVO1/SERVO3 |
| Cârmă | PWM H743 → servo 4806 | Nespecificat | De ales împreună cu motorul și alimentarea servo |
| Cuva stânga | PWM H743 → JX6221 | Ieșire 9 în aplicație | Implicit software, nu pin validat; V3 cere concordanță cu serviciul |
| Cuva dreapta | PWM H743 → JX6221 | Ieșire 10 în aplicație | Implicit software, nu pin validat |
| Far | GPIO H743 → PCB V3 J5 | S6, GPIO55 propus anterior | Maparea și disponibilitatea se verifică pe firmware-ul ales |
| Poziții | GPIO H743 → PCB V3 J6 | S7, GPIO56 propus anterior | Aceeași verificare; semnal digital, nu alimentarea luminilor |
| Excitație sondă apă | GPIO H743 → PCB V3 J12 | S8, GPIO57 propus anterior | Nu activăm înainte de verificarea circuitului și a măsurărilor |
| RGB | Ieșire serialLED → PCB V3 J7; LED la J8 | S13 / pad LED propus | Se verifică aliasul padului, suportul serialLED și ordinea culorilor |
| Temperatură baterie | PCB V3 J10 → ADC H743 | RSSI / PC5 / ADC8 propus | Numerotare ADC și divizor Rev F de verificat; NTC la J9 |
| Apă măsurare | PCB V3 J12 → ADC H743 | CU2 / PA7 / ADC7 propus | Se verifică front-end-ul ADC și domeniul de tensiune; electrozi la J11 |
| GR01 comandă RC | GR01 SBUS → intrare RC H743 | Fără pad stabilit | Se verifică protocolul, inversia și intrarea potrivită |
| GR01 telemetrie | UART MAVLink H743 ↔ GR01 | TELEM generic în documentația veche | UART fizic și SERIALx nealocate |
| UM982 | UART H743 ↔ GNSS | UART/GPS generic | Se stabilesc conexiunile pentru poziție și heading conform modulului real |
| USR-TCP232-ED2 | UART ↔ Ethernet, dacă păstrăm această cale | Fără UART stabilit | Stabilim dacă MAVLink trece prin ED2, prin GR01 sau pe legături separate |
| Camera și Kogger | Rețea Ethernet planificată | Switch / GR01 / ED2 conform arhitecturii finale | Nu rezervăm ieșiri servo sau canale RC pentru date video/sonar |
| Nano UART | Nu există pe PCB V3 | UART4/J18 apare în documentele V2 | Învechit pentru V3; nu rezervăm UART4 automat |

În cod, cuvele au închis 1500 µs, deschis 1900 µs și durată 900 ms. Sunt puncte de plecare, **nu calibrarea mecanică a servo-urilor**. Serviciul V3 verifică ieșiri dedicate cu FUNCTION=135 și TRIM egal cu poziția închisă, plus concordanța calibrării trimise de aplicație. Compatibilitatea și revenirea la TRIM trebuie testate pe versiunea instalată.

### GR01: canale RC versus conectori PWM

Documentul arhivat de bază V2 consemnează PWM0–PWM2 asociate CH9–CH11. Această afirmație este păstrată ca **informație istorică de reverificat în manualul/revizia GR01**, nu ca pinout aprobat. Arhitectura NAVO folosește H743 pentru motor, cârmă și cuve; nu conectăm în paralel ieșiri active GR01 și H743 către același servo. Faptul că presetul folosește CH15/CH16 nu presupune că receptorul are 16 conectori PWM.

## Ce completăm după primirea fotografiilor și prima conectare

1. Revizia fizică H743/GR01, orientarea și etichetele conectorilor.
2. Firmware-ul ales și identificatorul exact de placă; înainte de instalare consultăm documentația oficială.
3. G20 Device Tool: asocierea fiecărui control cu CH1–CH16, fără schimbări inițiale.
4. Monitor RC: mișcăm un singur control pe rând, notăm canalul și min/neutru/max, sensul, momentary/latching și pozițiile comutatoarelor.
5. Decidem responsabilul fiecărei funcții: ArduPilot nativ, serviciu Lua sau aplicație. Evităm două căi care declanșează aceeași cuvă/lumină.
6. Definitivăm ieșirile și UART/ADC/GPIO, apoi salvăm primul `.param`, după configurare, împreună cu versiunea firmware.
7. Calibrare mecanică, senzori Rev F și teste de pierdere a legăturii / oprire aplicație / restart script.

### Fișă de verificare pe hardware

| Control fizic | Canal observat | Min / neutru / max | Sens / tip control | Responsabil final | Verificat la |
|---|---|---|---|---|---|
| Stick dreapta orizontal | De completat | — | — | — | — |
| Stick dreapta vertical | De completat | — | — | — | — |
| Control stânga / zoom | De completat | — | — | — | — |
| Comutator moduri | De completat | — | — | — | — |
| HOME, L1, R1, L2 | De completat separat | — | — | — | — |
| R2, CAMERA, STOP | De completat separat | — | — | — | — |

## Surse din proiect

- [Preset G20 și limitele integrării](../custom/G20_INTEGRATION.md)
- [Valorile implicite și listener RC](../custom/qml/NavoG20Controller.qml)
- [Interfața setărilor G20](../custom/qml/NavoG20Settings.qml)
- [Rutarea acțiunilor în Dashboard](../custom/qml/NavoDashboard.qml)
- [Serviciul V3 și protocolul](../ardupilot/NAVO_V3_SERVICE.md)
- [Configurația Lua, dezactivată](../ardupilot/modules/navo_v3_config.lua)
- [Inventarul migrării](NAVO_SMART/MIGRATION_V3_H743.md)
- [Arhiva V2 pentru GR01](NAVO_SMART/library/NAVO_SMART_V2_Baza_Proiectare.md)
- [Document H743 anterior, cu referințe V2](NAVO_SMART/H743_ARDUPILOT_UM982_GR01.md)

Vom actualiza acest registru după fiecare decizie. Un candidat devine „confirmat” doar când sunt notate sursa verificării, configurația firmware și rezultatul testului.
