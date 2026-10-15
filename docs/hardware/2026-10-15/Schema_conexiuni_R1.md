# NAVO SMART V3 - schema de conexiuni R1

15 octombrie 2026. Proiectare documentată, validare fizică restantă.

## 1. Arhitectura și limitele verificării

Schema R1 / 15 octombrie 2026. H743-WING V3 + GR01 + AK994/UM982 + USR-TCP232-ED2 + ES3EP-R V1.1 + Kogger BASIC 2D-Sonar+ + cameră IP generică.

Propunere de cablare pe baza fotografiilor și documentației. Nicio conexiune nu a fost măsurată pe banc; nu este încă o schemă integral validată pentru cositorire. Nicio setare nu a fost încărcată în H743 sau radio.

GR01: SBUS pentru control și UART separat pentru MAVLink. GNSS: UART2 pentru poziție/heading și I2C1 pentru busolă. Sonar: UART0 al ED2, apoi Ethernet. Cele trei porturi switch: GR01, ED2, cameră. Nu este necesar un al patrulea port.

IMPORTANT: Kogger BASIC 2D-Sonar+ este UART TTL, nu Ethernet nativ. Camera IP nu se conectează la padurile analogice C1/C2/VTX ale H743. UART0 al ED2 nu este UART0 al H743.

Legendă: D = documentat și/sau etichetat în poze; P = alocare aleasă pentru proiect; V = verificare fizică sau specificație încă necesară. Un rând D/P nu dovedește că lipitura existentă este corectă.

Album: 39 fișiere JPG, 35 imagini distincte; originale păstrate byte-cu-byte, inclusiv duplicatele. Indexul le leagă de numele inițiale și conține SHA-256.

## 2. H743 ↔ GR01: comandă și telemetrie

Alegere: ArduRover, țintă standard MatekH743. RX6 rămâne intrarea RC implicită (BRD_ALT_CONFIG=0); nu aplicăm automat rețeta pentru MatekH743-bdshot.

Ordinea TELEM/SBUS din manual: RX, TX, GND, SBUS, GND, de la capătul apropiat de PWM/UPDATE către capătul antenelor. În fotografia GR01-04, cu textul drept, corespunde stânga → dreapta. Privirea dinspre firele mufei este oglindită față de soclu; verifică fiecare conductor prin continuitate.

Folosește cablul GR01-PIX, păstrând capătul de receptor. Cositorește capetele identificate la padurile H743 sau la un adaptor. Nu introduce mufa PIX în portul USB SH6 ori în GH4 CAN/I2C al H743.

| ID | De la | La | Rol / statut |
| --- | --- | --- | --- |
| R01 | GR01 TELEM RX (contact 1*) | H743 TX7 | MAVLink: H743 transmite. D/P; V nivel logic 3,3V |
| R02 | GR01 TELEM TX (contact 2*) | H743 RX7 | MAVLink: H743 primește. D/P; V nivel logic 3,3V |
| R03 | GR01 TELEM GND (contact 3*) | H743 G | Referință UART comună. D/P |
| R04 | GR01 SBUS (contact 4*) | H743 RX6 | Control RC. D/P |
| R05 | GR01 SBUS GND (contact 5*) | H743 G lângă RX6 | Referință SBUS. D/P |
| R06 | GR01 PWM0-2 / UPDATE / KEY | Neconectate | Nu se leagă ieșirile PWM GR01 la ieșiri H743. |
| * | Numerele 1-5 sunt ale acestui dosar | Nu sunt marcaje fabricant | Confirmare la cablul real; nu după culoare. |

## 3. H743 ↔ AK994 / UM982 + IST8310

În GNSS-02 / REF-GNSS-03 privim în soclul receptorului, USB-C la dreapta și textul drept. Pinii 1-8 sunt de la stânga la dreapta. Nu număra din spatele mufei fără oglindire.

Cele două capturi noi REF-GNSS-02/03 indică 3-5,5V și modelul dual AK994. Alegere: 5V stabilizat extern. Nu 12V, nu bateria 4S. Aceasta este informația vânzătorului furnizată de utilizator, nu o măsurare a exemplarului.

Conexiunile UART și I2C directe presupun logică 3,3V. Verifică documentația completă sau nivelul semnalelor înainte de conectare; eticheta TTL singură nu specifică amplitudinea. Nu alimenta simultan prin VCC și USB fără confirmarea protecției la retur.

| Pin GNSS | Semnal | Destinație exactă | Statut |
| --- | --- | --- | --- |
| 1 | VCC | +5V extern stabilizat | D/P; sursă REF-GNSS-02 |
| 2 | GND | GND extern + H743 G | D/P |
| 3 | RX1 | H743 TX2 | D/P; V nivel logic |
| 4 | TX1 | H743 RX2 | D/P; V nivel logic |
| 5 | SDA | H743 DA1 | D/P; V pull-up la 3,3V |
| 6 | SCL | H743 CL1 | D/P; V pull-up la 3,3V |
| 7 | RX2 | Izolat, rezervă | Nu se unește cu RX1/TX1 |
| 8 | TX2 | Izolat, rezervă | Nu este necesar al doilea UART pentru dual-heading |
| RF | Master / secondary | Câte o antenă GNSS compatibilă | Identitatea SMA și sensul bazei: V |

## 4. Kogger BASIC 2D-Sonar+ ↔ ED2

Pinout din pagina producătorului Kogger: maro VCC, albastru GND, verde TX, portocaliu RX. Alimentare admisă 3,7-18V; pentru acest proiect alegem +5V extern, cu rezervă pentru vârful de 0,5A. Nu preluăm culorile pentru alte modele Kogger.

ED2 folosește logică UART 3,3V chiar când este alimentat la 5V. Pagina BASIC+ spune TTL fără amplitudine explicită: confirmă nivelurile BASIC+ înainte de legarea directă. Dacă TX sonar este 5V, este necesară adaptare de nivel dimensionată pentru baudrate; nu lega direct la ED2.

În ED2-02, cu scrisul drept, coloana stângă se numără de jos în sus 1-12; coloana dreaptă de sus în jos 13-23. Folosește și serigrafia pentru fiecare lipitură.

| ID | De la | La | Observație |
| --- | --- | --- | --- |
| S01 | Kogger TX / verde | ED2 RXD0 / pin 7 | Date sonar → rețea; V nivel logic |
| S02 | ED2 TXD0 / pin 6 | Kogger RX / portocaliu | Comenzi / setări sonar; V nivel logic |
| S03 | Kogger GND / albastru | GND comun / ED2 pin 11 sau 12 | Masă comună obligatorie |
| S04 | +5V extern | Kogger VCC / maro | Ramură separată, protejată |
| S05 | +5V extern | ED2 +5V / pin 13 sau 14 | Nu se alimentează și pinul +3,3V / 16 |
| S06 | GND extern | ED2 GND / pin 11 sau 12 | Retur alimentare |
| S07 | ED2 RXD1/TXD1, RXD2/TXD2 | Neconectate | Rezerve. Nu amesteca porturi UART. |

## 5. Ethernet: mini-switch, GR01, ED2, cameră

Etichete de proiect pentru switch, vedere ca în SW-01 (alimentare sus-dreapta): port A = mufa stânga-sus → GR01; port B = mufa dreapta-mijloc → ED2; port C = mufa dreapta-jos → cameră. Aceste litere nu sunt serigrafia producătorului.

Pe spate sunt marcate 1,2,3,6 lângă cele 4 contacte de port. Tabelul de mai jos folosește numerele de contact Ethernet, NU poziția 1-4 în mufa albă. Confirmă prin continuitate că respectivele marcaje corespund contactelor RJ45. Nu avem manual verificat pentru ES3EP-R V1.1.

LAN GR01, din manual: R-, R+, T-, T+ de la capătul KEY/SET către capătul antenelor. În fotografia GR01-03 cu textul drept, ordinea stânga → dreapta este T+, T-, R+, R-. Confirmă cablul R20 prin continuitate.

Schemă straight-through de la MDI către switch; dacă portul nu are auto-MDI/MDIX și nu apare link, verifică întâi cablajul și specificația portului. Nu inversa polaritatea în interiorul perechii.

| Contact switch A/B/C | A: GR01 LAN | B: ED2 | C: RJ45 cameră |
| --- | --- | --- | --- |
| 1 | T+ | ETH_TX+ / pin 1 | 1 (T568B: alb-portocaliu) |
| 2 | T- | ETH_TX- / pin 2 | 2 (T568B: portocaliu) |
| 3 | R+ | ETH_RX+ / pin 3 | 3 (T568B: alb-verde) |
| 6 | R- | ETH_RX- / pin 4 | 6 (T568B: verde) |
| Alte contacte | Nu se aplică | Nu se aplică | 4,5,7,8: fără alimentare în schema non-PoE |

## 6. Alimentare: ramuri separate, GND comun

Propunere pentru bateria 4S. Retururile de putere merg în distribuția de masă; nu trece curentul motorului prin firele de masă UART. Siguranțele se dimensionează după consumurile reale, curentul de pornire și secțiunea conductorului.

Nu pune în paralel ieșirea UBEC 5V extern cu 5V/4V5 al H743 și nici UBEC12V cu 9V/Vsw al H743. Se unesc masele, nu sursele pozitive. Vx este o alimentare servo separată.

Dacă UBEC12V este doar buck, la o baterie coborâtă spre 12V ieșirea poate cădea sub 12V. Pentru placa marcată minim 12V și camera 12V, verifică dropout-ul sau folosește un regulator buck-boost corespunzător.

| Consumator | Pozitiv | Negativ / observație |
| --- | --- | --- |
| H743 | Baterie prin protecția principală → BAT+ | Baterie − → BAT/ESC−; nu la 5V/4V5 |
| ESC motor | H743 ESC+ | H743 BAT/ESC−; nu ocoli șuntul dacă măsori curentul motorului |
| 470µF / 35V | Picior + → BAT+ | Picior − / bandă corp → BAT/ESC−; conductoare scurte |
| GR01 | 12V extern → POWER XT30 + | GND → XT30 −; manual 7,2-72V, fără alimentare din TELEM |
| Mini-switch | 12V stabilizat → + conector alimentare | GND → −; serigrafie 12-52V, polaritate de verificat |
| ED2 + Kogger + GNSS | Ramuri +5V externe separate | GND comun; GNSS numai 5V conform capturii actuale |
| Cameră IP generică | 12V extern → intrarea DC dedicată | GND → DC−; model ales trebuie să admită 12V și Ethernet 100M |
| Servo-uri | Vx H743 sau BEC servo separat, nu ambele | G comun; tensiunea se verifică pentru fiecare servo |

## 7. Cositorire și detalii de montaj

H743: cositorește numai firele necesare la etichetele TX7, RX7, RX6, G, TX2, RX2, DA1, CL1. Alimentarea GNSS în această schemă vine din UBEC5V extern. Etichetează ambele capete ale fiecărui fir cu ID-ul din tabel.

Placa H743 este stivuită. Fotografiile nu confirmă toate legăturile de alimentare între etaje; manualul Matek indică legături cu fire siliconice. Verifică Vbat, G și Vx pe ambele etaje înainte de a adăuga punți. Nu presupune că șuruburile și distanțierele transportă toate alimentările.

ED2: sunt disponibili pini de header. Preferă conector de cablu cu fixare mecanică; dacă lipești direct, izolează individual. RST, Reload, RTS/CTS și LED_LINK/DATA rămân neconectate pentru funcționare fără flow control.

Switch: preferă mufele existente. Dacă lipești pe spate, folosește contactele deja marcate 1,2,3,6 ale portului ales, după verificarea corespondenței. Nu lipi în footprinturi libere sau J4 doar fiindcă arată ca un port.

Ethernet: păstrează două perechi torsadate separate, 1-2 și 3-6; desfă-le cât mai puțin la lipitură. Nu folosi fire UART lungi sau un fir GND drept substitut pentru ETH_RX-/ETH_TX-. Nu lega perechile Ethernet la masă.

Camera generică din schemă: Ethernet 10/100, flux RTSP/H.264, alimentare DC 12V separată. Pentru o cameră exclusiv PoE trebuie adăugat echipament PoE compatibil; acest switch nu este demonstrat ca PSE.

Extensia H743 USB/buzzer: cablul original SH6, semnal-la-același-semn: 4V5, G, D-, D+, Boot, Buz-. Cele două GH4 sunt I2C2 și CAN. Pentru GNSS folosim padurile DA1/CL1, nu mufa CAN.

La punerea în funcțiune, lasă motorul fără elice și servo-urile fără sarcină mecanică. Prima pornire pe sursă limitată în curent; verifică separat fiecare ramură înainte de a cupla semnalele.

## 8. Configurare inițială și verificări rămase

Acestea sunt ținte pentru prima configurare, nu un fișier .param de încărcat orbește. Nu există încă firmware validat pe exemplarul din poze.

| Element | Propunere | Validare necesară |
| --- | --- | --- |
| Telemetrie | TX7/RX7 = SERIAL1; MAVLink2, 115200; flow control oprit | Aceeași viteză în G20/GR01; verifică MAVLink bidirecțional |
| Comandă RC | RX6 = RCIN pe MatekH743 standard, BRD_ALT_CONFIG=0 | Monitor 16 canale, sensuri, failsafe. Nu confunda CHx cu Sx |
| GNSS | TX2/RX2 = SERIAL3; SERIAL3_PROTOCOL=5; inițial 115200 | GPS1_TYPE=25 pentru UM982 dual heading; numele depinde de versiune |
| Busolă | SDA → DA1; SCL → CL1, I2C1 | Detectare IST8310, orientare și calibrare; pull-up compatibil |
| Sonar | ED2 UART0 transparent, 8N1; baud identic cu sonar | Inițial 115200; ajustează ecograma la banda disponibilă |
| Rețea | ED2 exemplu 192.168.144.30; cameră .40; /24 | Adrese propuse, nu valori din fabrică; verifică lipsa conflictelor |
| Transport sonar | TCP server ED2, exemplu port 5000, client NAVO | Numai dacă aplicația folosește TCP; altfel configurează UDP coerent |
| Camera | RTSP real al modelului ales, H.264, bitrate inițial modest | Test link LAN și video prin G20; nu presupune URL universal |
| GPS yaw | Două antene GNSS, bază de minimum 30cm | Identifică master/secondary; măsoară offseturile și verifică heading |

## 9. Lista scurtă înainte de execuție

1. GR01: fotografiază/identifică fiecare contact al mufei de cablu și verifică prin continuitate că RX, TX, cele două GND și SBUS ajung la firele etichetate R01-R05. Confirmă amplitudinea TX și SBUS. UART7 H743 este 3,3V.

2. Mini-switch: confirmă cu multimetrul polaritatea conectorului de alimentare și corespondența fiecărui contact cu inscripțiile 1,2,3,6. Un link sau manual de la vânzător ar elimina presupunerile despre porturi/auto-MDI-X.

3. GNSS: capturile noi rezolvă tensiunea nominală a AK994 (3-5,5V). Mai rămân nivelul UART/I2C și identificarea porturilor RF master/secondary; nu aplica tensiunea antenei AK161 pe VCC-ul receptorului.

4. Sonar: confirmă că exemplarul comandat este BASIC 2D-Sonar+ cu cele patru culori documentate și UART compatibil 3,3V. Manualele modelelor Enhanced sau Side-view nu substituie pinoutul BASIC+.

5. H743: confirmă alimentarea între etaje, polaritatea condensatorului, tensiunile și absența scurturilor. Nu scurtcircuita BAT+ cu ESC+ și nu unește două BEC-uri.

6. Integrare: testează separat RC, MAVLink, GNSS/heading, sonar și video; apoi simultan. O imagine video funcțională nu dovedește acces TCP/UDP la ED2. Verifică traseul de rețea G20 până la IP-ul ED2.

În stadiul R1, traseele și capetele de semnal sunt definite; punctele V de mai sus împiedică declararea întregului ansamblu drept gata de cositorire fără măsurători.

## 10. Surse și trasabilitate

Consultate 15 octombrie 2026. Manualul Matek V2 este folosit pentru detalii comune observabile și comparat cu placa V3 reală și hwdef ArduPilot; nu este folosit pentru a declara că IMU-ul V3 ar fi MPU6000. URL-ul original Matek a răspuns 404, deci este indicată explicit copia documentului fabricantului.

GNSS: REF-GNSS-02/03 și GNSS-02 sunt probele pentru AK994, 3-5,5V și conectorul cu 8 pini. Switch: SW-01/02/03 sunt singurele probe identificate pentru exemplarul ES3EP-R V1.1. Documentația verificată a fabricantului switchului nu a fost găsită.

Raportul folosește sursele pentru interfețe și limite. Alocarea porturilor switch, alimentările de proiect, ID-urile de cablu și adresele IP sunt alegeri de integrare, nu valori citite din echipamente.

| ID | Document / utilizare | URL |
| --- | --- | --- |
| K1 | Kogger BASIC 2D-Sonar+; pinout și alimentare | https://kogger.tech/product/basic-2d-sonar-2/ |
| K2 | Kogger: conectare UART și debit ecogramă | https://kogger.tech/getting-started-with-kogger-sonar/ |
| U1 | USR-TCP232-ED2 Hardware Manual v1.0.1.01, p.4-7 | https://www.pusr.com/download/M4/USR-TCP232-ED2-Hardware-Manual_V1.0.1.01.pdf |
| G1 | Skydroid G20 manual V1.0, copie Airmobi; p.6 GR01 | https://www.airmobi.com/wp-content/uploads/2025/04/Skydroid-G20-Ground-Control-Station-User-Manual.pdf |
| H1 | ArduPilot Rover: MatekH743, UART și RCIN | https://ardupilot.org/rover/docs/common-matekh743-wing.html |
| H2 | ArduPilot: definiția hardware MatekH743 (master, consultată la data raportului) | https://raw.githubusercontent.com/ArduPilot/ardupilot/master/libraries/AP_HAL_ChibiOS/hwdef/MatekH743/hwdef.dat |
| H3 | Matek H743-WING V2 Quick Start 09/2021; copie a documentului fabricantului | https://device.report/m/6a3f5ae209a6b4ab37ea5f151d7b50a1dd40034ed2c94238505032661d5b9ab4 |
| N1 | ArduPilot: GPS for Yaw, UM982 | https://ardupilot.org/copter/docs/common-gps-for-yaw.html |

## Fotografii

Vezi Index_fotografii.csv și albumul PDF.
