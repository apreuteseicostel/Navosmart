# NAVO SMART V2 — baza electrică pentru reproiectare

Revizie de lucru V2-P2 • 28 septembrie 2026

**Stare: arhitectură și specificație electrică preliminară. Nu este schemă CAD finală, PCB rutat sau pachet de fabricație.**

## 1. Baza documentară și limitele recuperării

Au fost inspectate cele cinci fișiere primite: NAVOMODEL_RevD_Desene.pdf, BOM_JLC.csv, Positions_All_JLC_Positive.csv, Gerbers_JLC_Positive.zip și NAVOMODEL_Asamblare_v2.zip. Schema din arhiva de asamblare este RevD D0.1 din 16 septembrie 2026. Arhiva de asamblare are o selecție comercială revizuită din 17 septembrie; sufixul «v2» al acesteia nu înseamnă noua placă NAVO SMART V2.

Nu există în arhive fișiere .kicad_sch/.kicad_pcb/.kicad_pro. Gerberele nu înlocuiesc schema și conexiunile CAD editabile. Reproiectarea necesită reconstruirea schemei și realizarea unui PCB nou.

Contextul recuperat din ultima discuție confirmă dimensiunea alungită, eliminarea modulului Pololu, sursele integrate, UART dedicat și serigrafia completă. Nu s-a recuperat un transcript integral; cerințele nespecificate nu sunt prezentate aici ca acorduri anterioare.

## 2. Cerințe preluate

| Element | Cerință V2 |
|---|---|
| Nume | NAVO SMART V2 |
| Formă | Lungă și îngustă, țintă 105–120 × 50–60 mm; dimensiunea se închide după placement |
| Baterie | Li-ion 4S, maximum 16,8 V; domeniul de proiectare discutat 12–16,8 V |
| Controller | Arduino Nano clasic 5 V, detașabil, acces la USB |
| 12 V | Convertor integrat pe PCB, eliminarea Pololu |
| 5 V | Convertor integrat pentru poziții, logică, RGB și buzzer |
| Autopilot | Matek H743-WING V3; conector dedicat de telemetrie Nano–H743 |
| Senzori | Tensiune baterie, NTC baterie, apă în carenă cu diagnostic |
| Ieșiri | Far, poziții, RGB adresabil, buzzer |
| Cuve | Două pass-through-uri de servo cu monitorizare PWM |
| Canal suplimentar D0.1 | Se păstrează funcția de monitorizare/pass-through T până la clarificarea rolului, fără comandă de cârmă din Nano |
| Sonar | Alimentare filtrată; datele Ethernet nu traversează această placă |
| Montaj | Prioritate pieselor asamblabile la JLCPCB; Nano pe socluri |
| Service | Conectori pe margini, polaritate și funcție pe fiecare pin, puncte de test accesibile |

## 3. Corecții identificate înainte de redesenare

1. **GR01 nu se alimentează la 5 V prin intrarea sa principală.** Manualul G20 pentru GR01 indică 7,2–72 V la XT30. Schema veche J5 = GR01_VBAT este coerentă cu alimentarea 4S. V2 păstrează ramura din baterie, cu protecție și siguranță proprii. Nu se transferă această concluzie la alte modele de receptor.
2. **PWM fizic nu este același lucru cu numărul canalului radio.** Manualul indică PWM0–PWM2 = CH9–CH11. Pentru funcțiile logice CH5/CH6 se folosesc ieșiri H743 configurate corespunzător sau se remapează comenzile radio. Nu se conectează ieșirea PWM a H743 în paralel cu ieșirea GR01.
3. **S13V25F12 este buck-boost.** Înlocuirea cu un buck simplu schimbă comportamentul la baterie descărcată. LMR51430 are duty-cycle maxim declarat 98%; la intrare 12 V, chiar limita ideală ar fi 11,76 V înaintea pierderilor. Nu poate fi promisă o ieșire stabilizată de 12 V pe întregul domeniu 12–16,8 V.
4. **Iluminatul este clarificat de utilizator la 28 septembrie 2026:** far de 10 W, stabilizat prin driver propriu, alimentat direct din bateria 4S; poziții la 5 V. Aceste date înlocuiesc cerințele vechi de poziții la 12 V și far de până la 30 W. Farul folosește ramura VBAT protejată și MOSFET; pozițiile trec pe ramura de 5 V protejată separat.
5. **UART nou, nu doar o mufă.** Se proiectează adaptarea nivelurilor, comportamentul cu o placă oprită și izolarea față de USB/programare. Conectorul singur nu implementează telemetria ArduPilot.
6. **PWM de cuvă nu dovedește deschiderea mecanică.** V2 raportează comandă/impuls observat; pentru confirmare fizică ar fi necesar un senzor suplimentar, care nu este inclus în această bază.

## 4. Arhitectură electrică propusă

### Intrare și distribuție

J1 BAT_4S → siguranță principală → protecție la inversarea polarității → magistrală VBAT_PROT. Protecția la impulsuri se dimensionează împreună cu limitele convertoarelor și siguranței; nu se alege TVS doar după tensiunea nominală de 16,8 V.

Din VBAT_PROT pleacă separat: GR01 prin siguranță proprie; convertorul de 5 V; convertorul de 12 V; ramura farului de 10 W cu driver propriu, alimentat din baterie conform precizării utilizatorului. ESC/motorul rămân pe distribuția lor de putere. Masa este comună pentru semnale, dar returul motorului nu trece prin placa auxiliară.

Sursa de 5 V alimentează pozițiile, Nano, RGB și buzzer. Utilizatorul a precizat maximum 1 A pentru poziții, interpretat ca totalul lor în contextul întrebării despre consumul împreună: maximum 5 W. Ținta de proiectare a sursei este 5 V / 2 A continuu (10 W), cu până la 1 A disponibil pentru logică, RGB, buzzer și rezervă. Aceasta este o țintă, nu o performanță validată; suma consumurilor auxiliare, curentul de pornire, inductanța și temperatura în carcasă trebuie verificate. Servourile rămân alimentate separat.

Pentru 12 V stabil până la intrare 12 V, baza funcțională este un convertor buck-boost integrat. Un buck mai simplu rămâne posibil numai dacă toate sarcinile acceptă scăderea tensiunii la capătul descărcării. Această abatere nu este adoptată implicit.

### Bugetul de putere

| Sarcină | Date disponibile | Consecință |
|---|---|---|
| Poziții | 5 V, maximum 1 A total precizat de utilizator | Maximum 5 W |
| Sursa de 5 V | 2 A continuu, țintă de proiectare | 10 W total; verificare termică și buget auxiliari înainte de validare |
| Far | 10 W, driver propriu, direct din baterie | Dacă 10 W este consumul de intrare: circa 0,60–0,83 A la 16,8–12 V; dacă este puterea LED, se adaugă pierderile driverului |
| Ramura 12 V | Iluminatul nu mai este conectat aici | Se dimensionează pentru sonar și doar sarcinile suplimentare confirmate |
| Sonar | Model discutat Kogger Basic 2D Plus | Consum de vârf și domeniu de tensiune încă de verificat |
| GR01 | Manual: punct de funcționare 12 V/300 mA | Nu reprezintă garantarea curentului maxim sau de pornire |

Nu se copiază automat siguranța principală veche de 5 A. Se recalculează bugetul total, pierderile, impulsurile de pornire și temperatura pentru farul de 10 W pe VBAT și pozițiile pe 5 V. Eticheta de 3 A a unui circuit integrat nu garantează 3 A continuu în carcasa închisă.

### Ieșiri și stări implicite

Far și poziții: MOSFET-uri comandate de Nano, cu gate pulldown, rezistență serie și stare OFF la reset. Selecția MOSFET-ului se bazează pe RDS(on) la tensiunea reală de comandă, nu pe tensiunea de prag. Curentul de pornire al lămpilor se include în verificare.

Sonar: alimentare separată filtrată; filtrul se verifică pentru curent, cădere de tensiune și rezonanță. La subtensiune software, se reduc/opresc luminile conform cerinței, fără tăierea arbitrară a receptorului sau sonarului. BMS-ul bateriei rămâne responsabil pentru protecția finală a celulelor; tensiunea totală nu detectează dezechilibrul dintre celule.

LED-uri locale de prezență 5 V/12 V sunt o propunere de service. Ele arată prezența tensiunii, nu certifică faptul că tensiunea este corectă sub sarcină.

## 5. Alocare Nano

Alocarea D2–D12/A0–A2 este citită din pagina Controller a schemei vechi. UART folosește D0/D1, neconectate extern în D0.1.

| Pin Nano | Funcție V2 | Observație |
|---|---|---|
| D0/RX | Date din H743 | Prin interfață și deconectare de service |
| D1/TX | Date către H743 | Adaptare 5 V către nivelul UART H743 |
| D2 | RC_A_N | Intrare inversată prin buffer |
| D3 | RC_B_N | Intrare inversată prin buffer |
| D4 | RGB_TX | Rezistență serie către LED extern |
| D5 | MON_L_N | Monitorizare cuvă stânga |
| D6 | MON_R_N | Monitorizare cuvă dreapta |
| D7 | MON_T_N | Monitorizarea celui de-al treilea canal D0.1 |
| D8 | HEAD_CTL | Far |
| D9 | POS_CTL | Poziții |
| D10 | BUZZ_CTL | Buzzer |
| D11 | WATER_EXC | Excitație sondă apă |
| D12 | ACK_N | Confirmare locală alarmă |
| A0 | BAT_ADC | Tensiune baterie |
| A1 | TEMP_ADC | NTC |
| A2 | WATER_ADC | Sondă apă |
| D13, A3–A7 | Rezervă | A6/A7 numai analogic pe Nano clasic |

Bufferul HCT14 inversează semnalele: firmware-ul trebuie să interpreteze corect durata impulsului inițial. Citirea PWM, actualizarea RGB și UART trebuie verificate împreună pentru pierderi de impulsuri/bytes.

## 6. Conectori V2 — contract preliminar

Numerotarea păstrează funcțiile D0.1 și adaugă J18. Numerele de pin de mai jos definesc conexiunea electrică; orientarea fizică se verifică în CAD și pe cablaj înainte de montaj.

| Ref. | Funcție | Pini / observații |
|---|---|---|
| J1 | BAT_4S | BAT+, GND |
| J2 | FAR_10W_VBAT | VBAT protejat prin siguranță, RETUR_COMUTAT; driver în far |
| J3 | POZITII_5V | +5V protejat separat, RETUR_COMUTAT |
| J4 | SONAR | +12V filtrat, GND |
| J5 | GR01 | VBAT protejat și siguranță proprie, GND |
| J6 | RC_A / RC_B | 1 GND, 2 PWM_A, 3 PWM_B; fără pin de alimentare |
| J7/J8 | H743_L / SERVO_L | 1 GND, 2 V_SERVO_L, 3 PWM_L |
| J9/J10 | H743_R / SERVO_R | 1 GND, 2 V_SERVO_R, 3 PWM_R |
| J11/J12 | H743_T / SERVO_T | 1 GND, 2 V_SERVO_T, 3 PWM_T |
| J13 | BUZZER | +5V, retur comutat |
| J14 | RGB | 1 GND, 2 +5V, 3 DATA |
| J15 | TEMP | NTC, GND |
| J16 | WATER | DRIVE, RETURN; rezistor EOL extern la sondă |
| J17 | ACK | ACK_N, GND |
| J18 nou | UART_H743 | 1 GND, 2 TX_TO_H743, 3 RX_FROM_H743, 4 +5V_OPT |

V_SERVO_L/R/T sunt trasee de pass-through din alimentarea externă a servourilor, separate de +5V_LOGIC. Nu se unesc surse BEC între ele. Pinul 4 J18 este deconectat implicit; nu este destinat alimentării H743 întreg prin această mufă. Rolul său se fixează înainte de cablare.

Pentru service se prevăd separarea alimentării Nano de +5V_LOGIC și deconectarea ambelor linii UART externe. Scoaterea numai a jumperului de 5 V nu elimină toate căile de back-power prin pini. Pentru prima revizie, Nano detașabil permite programarea scos din placă; procedura de programare în circuit se validează separat.

## 7. Senzori și diagnostic

Tensiune: rețeaua veche este 100 kΩ/22 kΩ cu 100 nF. La 16,8 V rezultă aproximativ 3,03 V pe ADC. Se păstrează funcția, dar impedanța echivalentă de circa 18 kΩ și stabilizarea după schimbarea canalului ADC se verifică înainte de adoptarea valorilor. Se calibrează referința ADC; 5 V nominal nu este o referință exactă.

NTC: se păstrează sonda nominală 10 kΩ/B3950, cu verificarea modelului cumpărat. Se separă stările temperatură validă, sondă deconectată și scurtcircuit. Pragurile nu se îngheață fără limitele bateriei și poziția sondei.

Apă: se păstrează principiul sondei cu EOL 1 MΩ montat la capătul cablului. Excitația se face intermitent; firmware-ul diferențiază pe cât permite circuitul uscat/ud/cablu rupt/scurt. Pragurile se măsoară cu sonda reală și apă cu conductivitate diferită. Clampele ADC trebuie verificate și cu Nano nealimentat.

Telemetrie propusă: UART hardware 38400 baud, 8N1, mesaje scurte cu versiune, număr de secvență și CRC, circa 5 Hz. Aceasta este o propunere nouă, nu un protocol deja implementat. Integrarea în H743 necesită parser/driver sau Lua compatibil cu firmware-ul ArduPilot efectiv instalat; simpla conectare TX/RX nu face senzorii vizibili în aplicație. O legătură stale trebuie marcată invalidă, nu afișată ca date proaspete.

## 8. Amplasare și asamblare

Țintă mecanică inițială 115 × 55 mm. Zona intrării și a convertoarelor la un capăt, Nano în zona centrală cu USB accesibil, senzori/UART la capătul opus. Conectorii de putere aproape de ramurile lor. Se rezervă spațiu pentru mufele conectate, acces la siguranțe și șuruburi, nu doar pentru conturul componentelor.

Retururile de far/poziții și buclele comutate ale convertoarelor se țin departe de ADC și filtrul sonar. Planul de masă trebuie să ofere retur continuu semnalelor; nu se taie arbitrar în insule. Numărul de straturi și cuprul se fixează după alegerea sursei de 12 V și verificarea termică.

JLCPCB: arhiva veche avea 48 plasări SMD / 16 linii BOM și 26 poziții de montaj manual. Aceste numere nu se aplică V2. Prioritatea este reducerea montajului manual prin convertoare integrate și MOSFET-uri SMD. Soclurile Nano și conectorii pot necesita montaj THT sau serviciu dedicat.

Pentru fiecare piesă V2 sunt necesare MPN exact, capsulă, pinout, cod JLC și verificarea stocului/cantității la comandă. **În această etapă nu este verificat sau rezervat niciun stoc JLC pentru V2.** LMR51430 este doar un candidat analizat pentru 5 V; nu este o selecție aprobată pentru railul stabilizat 12 V.

## 9. Ce este făcut și ce blochează finalizarea

- [x] Inventar al documentelor și separarea D0.1 de noul V2.
- [x] Recuperare a cerințelor recente disponibile.
- [x] Audit preliminar alimentare GR01, PWM, conversie 12 V și UART.
- [x] Alocare Nano și contract preliminar pentru conectori.
- [x] Clarificare utilizator: far 10 W cu driver propriu, alimentare din baterie; poziții 5 V.
- [x] Consum poziții: maximum 1 A total la 5 V.
- [x] Țintă sursă de 5 V: 2 A continuu.
- [ ] Validarea consumurilor auxiliare și a funcționării termice a sursei de 5 V.
- [ ] Verificarea domeniului de alimentare și curentului maxim pentru sonarul exact.
- [ ] Selecție convertoare/protecții, calcule și verificare disponibilitate JLC.
- [ ] Reconstrucție CAD, ERC și revizie conexiune cu conexiune.
- [ ] Placement, rutare, dimensionarea traseelor, DRC și verificare termică.
- [ ] BOM/CPL/Gerbere V2 coerente, verificarea orientărilor în montaj.
- [ ] Prototip: teste la 12 V și 16,8 V, sarcină, pornire, reset, USB/UART și senzori.

Clarificările iluminatului sunt închise pentru arhitectură: far 10 W pe VBAT cu driver propriu și poziții 5 V / maximum 1 A total. Se poate continua selecția sursei de 5 V pentru ținta de 2 A continuu, reconstrucția schemei și verificarea sarcinii sonarului. Curentul siguranței pozițiilor se alege după impulsul de pornire și capacitatea cablului/traseelor, nu se fixează automat la 1 A.

## 10. Surse tehnice consultate

- Schema și notele D0.1 furnizate: Schematic.pdf, paginile Power, Controller, Inputs, Sensors și ASSEMBLY_NOTES_EN.txt / CITESTE_INAINTE_DE_INCARCARE.txt.
- Manual Skydroid G20, secțiunile GR01 și parametri receptor, copie a manualului găzduită de Airmobi: https://www.airmobi.com/wp-content/uploads/2025/04/Skydroid-G20-Ground-Control-Station-User-Manual.pdf
- Pololu S13V25F12, topologie și limite: https://www.pololu.com/product/4984
- Texas Instruments LMR51430, topologie buck și duty-cycle maxim: https://www.ti.com/product/LMR51430

Datele de produs au fost consultate în această sesiune; stocurile și prețurile nu sunt validate prin acest document.