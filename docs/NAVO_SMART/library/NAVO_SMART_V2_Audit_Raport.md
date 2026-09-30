# NAVO SMART V2-E0 — audit electric și verificare exporturi

Data: 29 septembrie 2026. Verdict: **NU TRIMITEȚI E0 LA FABRICAȚIE/ASAMBLARE.**

Revizia verificată este NAVO_SMART_V2_E0_Prototip.zip, SHA-256: `0b7ff5855a78f186c02a6713516fc50da10bba87a5d58523530fb39df12a046a`.

Acest raport înlocuiește orice interpretare a rezultatului anterior „0 DRC” ca aprobare electrică. DRC-ul anterior verifica respectarea schemei introduse; o eroare prezentă simultan în schemă și PCB poate trece această verificare. În această etapă nu s-au modificat schema, PCB-ul sau exporturile E0. Corecțiile de mai jos sunt cerințe de închidere, nu schimbări deja implementate.

## 1. Probleme care blochează aprobarea

| ID | Constatare în proiectul efectiv | Consecință | Corecție necesară |
|---|---|---|---|
| B1 | U1 SN74HCT14: pad 12=GND, pad 13 neconectat. În realitate 12=6Y, 13=6A. Inclusiv denumirile simbolului sunt inversate. | Ieșire conectată la masă și intrare flotantă; poate apărea curent excesiv dacă ieșirea comandă nivel înalt. | Pin 13 la GND; pin 12 NC. Corectarea simbolului și rerutarea, nu doar schimbarea textelor. |
| B2 | L1 SWPA6045S6R8MT este catalogat 3 A RMS/4,3 A saturație; L2 SWPA6045S120MT 2,2 A RMS/2,8 A saturație. LMR51430 are limita de vârf tipică 4,76 A, maxim 6,68 A. | Curentul normal poate fi acceptabil, dar selecția nu asigură marja cerută de TI la supracurent. Fuzibilul de ieșire nu substituie protecția în fiecare ciclu. | Selectarea inductoarelor cu curent de saturație și curbe la temperatură adecvate limitei maxime, sau schimbarea regulatorului/protecției cu recalculare. |
| B3 | Rutarea automată a surselor: U2_SW total 17,49 mm, din care 12,45 mm la 0,25 mm; U3_SW total 21,12 mm. Feedback U2_FB=11,47 mm și U3_FB=25,43 mm. | Geometrie neconvingătoare pentru surse în comutație; risc de zgomot, supratensiuni de comutație și reglaj perturbat. Lungimile sunt suma segmentelor netului, nu o simulare a buclei. | Reamplasare și rutare locală manuală a VIN/GND, bootstrap, SW, inductoarelor și feedback-ului conform recomandărilor TI. Revizuirea cuprului termic și a retururilor. |
| B4 | TEMP_ADC are 176,63 mm de segmente, inclusiv ocolirea unei mari părți a plăcii. | Intrare analogică expusă cuplării din sursele în comutație și servouri. Nu afirmăm că produce neapărat o eroare, dar nu aprobăm această geometrie fără remediere. | Traseu scurt, filtrare aproape de pinul Nano, retur GND apropiat și separare față de SW. |
| B5 | ERC nu a fost executat; majoritatea pinilor simbolurilor personalizate sunt pasivi. | Verificarea schemă–PCB confirmă aceeași conexiune în două fișiere, nu corectitudinea ei față de componentă. B1 demonstrează această limită. | Tipuri electrice corecte, verificare ERC cu excepții justificate și control independent al pinilor înainte de reexport. |

Documentația TI pentru HCT14 confirmă 6A=13 și 6Y=12. Pentru LMR51430, secțiunea 9.2.2.4 cere curent de saturație peste limita de vârf; secțiunea 9.4 cere trasee scurte, bypass local și feedback apropiat de FB. Nu există o lungime maximă numerică dată de TI: respingerea amplasării E0 este o apreciere de proiectare pe baza geometriei măsurate, nu o limită inventată.

## 2. Pinaje și topologii revizuite

| Etaj | Observație |
|---|---|
| U1 | Primele cinci porți și alimentarea 7=GND/14=5 V sunt mapate coerent; a șasea poartă este greșită, conform B1. |
| U2/U3 LMR51430 | 1 GND, 2 SW, 3 VIN, 4 FB, 5 EN, 6 CB: maparea din schemă este corectă. EN la VIN este permis de fișa TI. Bootstrap este între CB și SW. Corectitudinea pinajului nu validează rutarea. |
| U4 AP2112K | 1 VIN, 2 GND, 3 EN, 4 NC, 5 OUT: mapare coerentă cu SOT25. Intrarea UART_VIN trebuie să fie 5 V, nu tensiunea bateriei. |
| U5/U6 SN74LVC1T45 | 1 VCCA=Nano5, 2 GND, 3 A, 4 B, 5 DIR, 6 VCCB=3,3 V. TX are DIR sus, RX DIR jos: direcțiile sunt corecte. |
| Q1 AOD4184A | 1 G, 2 D/tab, 3 S; returul farului este comutat, sursa la GND. |
| Q2/Q3 AO3400A | 1 G, 2 S, 3 D: conexiunile pentru poziții și buzzer sunt coerente. |
| Q4 IRF4905STRLPBF | D la intrarea după fuzibil, S spre VBAT protejat, G tras spre GND: orientarea inversă D/S este intenționată pentru protecția de polaritate. Zenerul este K la S și A la G. Nu trebuie „corectat” după o schemă obișnuită de comutator P-MOS. |
| D2/D3/D4 BAT54S | 1 A1=GND, 2 K2=Nano5, 3 nod comun=ADC: polaritatea clemelor este corectă. |
| Nano clasic | Alimentare la pin 27 (+5 V), pinii 4/29 GND, VIN neconectat; D1 TX/D0 RX prin punți. Nu se aplică automat altui model din familia Nano. |
| J18/JP4 | J18.4 este intrare 5 V de la H743; JP4.1–2 selectează această sursă, JP4.2–3 sursa locală. Nu sunt două ieșiri BEC legate direct în paralel. |

Acesta este un control al mapării electrice, nu confirmarea rotațiilor din biblioteca de asamblare JLCPCB sau o metrologie completă a fiecărei amprente.

## 3. Curente și tensiuni calculate

Calcule pentru Vin 12–16,8 V, cupru presupus 35 µm/1 oz; valorile sunt estimări, nu măsurători.

| Funcție | Calcul | Evaluare |
|---|---|---|
| Far | Pentru 10 W absorbiți: 0,595 A la 16,8 V și 0,833 A la 12 V. Dacă 10 W reprezintă puterea LED, consumul este mai mare în funcție de randamentul driverului. | F2=2 A permite regimul nominal; curentul de pornire trebuie verificat. Driverul trebuie să accepte efectiv 16,8 V. |
| Poziții | 5 V × 1 A = 5 W | F3=1,5 A și Q2 sunt nominal plauzibile. La 5 V, RDS(on) AO3400A max. specificat la 4,5 V este 32 mΩ, deci circa 32 mW la 1 A, înaintea creșterii la cald. |
| Sursa 5 V | 0,6 × (1+100/13,7) = 4,980 V nominal | Valoare corectă. 2 A este buget TOTAL: poziții + Nano + RGB + buzzer + logică. Nu sunt 2 A disponibili suplimentar după poziții. |
| Sursa sonar | 0,6 × (1+100/5,23) = 12,072 V nominal | Buck, nu buck-boost: nu menține această tensiune la Vin=12 V. Acceptabilitatea depinde de intervalul real al sonarului. |
| L1 la ieșire 2 A | La 16,8 V și 500 kHz: ripple 1,033 A p-p; vârf ≈2,516 A. La L −20% și frecvență 450 kHz: vârf ≈2,717 A. | Regimul normal nu explică singur B2; problema este marja la defect/supracurent. Calculele ignoră neliniaritatea L cu curentul și temperatura. |
| L2 la ieșire 0,5 A | Model CCM: ripple ≈0,571 A p-p, vârf ≈0,786 A. Cu L −20% și 450 kHz: vârf ≈0,897 A. | Nominal plauzibil. La sarcină mică PFM modelul CCM nu descrie impulsurile reale. |
| Baterie ADC | 16,8 × 10/(47+10) = 2,947 V; R echivalent ≈8,246 kΩ | În intervalul ADC alimentat la 5 V. Factor conversie nominal 5,7, cu calibrare după Vref și rezistențe. |
| NTC 10 kΩ la 25 °C | Rezistorul serie 1 kΩ participă la divizor: ADC ≈2,619 V la 5 V | Firmware-ul trebuie să scadă cei 1 kΩ; utilizarea formulei standard fără această corecție introduce eroare. |
| Apă EOL | EOL 1 MΩ: ≈0,450 V; cablu întrerupt: ≈0 V; scurt senzor: ≈4,505 V | Valori ideale cu excitație 5 V. Pragurile, contaminarea și excitația pulsată trebuie implementate în firmware. |

Exemplu de buget la Vin=12 V: 5 V/2 A și sonar 12 V/0,5 A, ambele cu randament ipotetic 90%, plus far 10 W absorbiți → aproximativ 2,31 A din baterie, **la care se adaugă GR01**. F1=5 A nu este un limitator precis de curent și nu validează termic traseele. Lipsesc consumul maxim real GR01 și consumurile RGB/buzzer; nu se poate certifica bugetul complet.

Traseele servo sunt de 1 mm și au lungimi totale de 60–80 mm. Pentru un singur traseu de 79,5 mm, rezistența ideală la 20 °C este circa 39 mΩ; la 3 A rezultă circa 0,117 V și 0,35 W numai pe conductorul pozitiv. Returul, conectorii, toleranța cuprului și temperatura adaugă pierderi. Nu este o certificare de 3 A. Sunt necesari curenții de blocare ai servourilor și analiza traseului GND; pentru servouri de putere este preferabilă alimentarea distribuită extern.

## 4. Alimentări oprite și protecții

- Cu JP1 scos și bateria conectată, divizorul bateriei poate injecta curent prin BAT54S în Nano5. Estimare de ordinul 0,3 mA, dependentă de tensiunile reale; izolarea Nano nu este totală. Semnalele RC/servo active pot injecta suplimentar prin clemele HCT14. Rezistențele limitează curentul, dar nu garantează absența alimentării parazite.
- Pentru programare, recomandarea de a scoate Nano din placă rămâne necesară. Pentru funcționare cu domenii alimentate separat trebuie reproiectată/validată secvențierea și izolarea.
- Fuzibilele nu garantează protecția MOSFET-urilor în orice scurtcircuit. Trebuie verificată coordonarea timp-curent, TVS și energia cablajului.
- Condensatoarele ceramice de intrare nu constituie singure o validare a conectării la cald pe fire lungi. TI menționează necesitatea posibilă a capacității bulk; sunt necesare verificări de amortizare și de transient.
- Nu există protecție hardware completă de descărcare profundă a bateriei. Este necesar BMS; măsurarea tensiunii și firmware-ul de avertizare nu îl înlocuiesc.
- Retururile farului/pozițiilor sunt comutate: nu trebuie legate extern la masa comună a bărcii, altfel se ocolește MOSFET-ul.

## 5. Verificarea coordonatelor pozitive

Verificare programatică pe fișierele din ZIP-ul Gerber livrat și pe CPL/BOM:

| Fișier/date | Rezultat |
|---|---|
| CPL | 82 rânduri; X=8,5…106,5 mm; Y=11,5…54 mm; toate pozitive |
| Rotații CPL | 0° și 90°; fără valori negative |
| BOM | 31 rânduri grupate, 82 componente total; toate cantitățile pozitive; aceleași referințe ca în CPL |
| Contur PCB | X=0…120 mm, Y=0…65 mm |
| Gerber cupru/față-verso | Coordonate nenegative; FilePolarity=Positive |
| Excellon PTH/NPTH | Coordonate pozitive |
| Mască soldermask | Coordonate pozitive, FilePolarity=Negative — normal pentru reprezentarea deschiderilor în mască |

BOM nu conține coordonate. „Coordonate pozitive” și „polaritate Gerber pozitivă” sunt două lucruri diferite. **Nu schimbați artificial polaritatea măștii în Positive și nu transformați coordonatele prin valoare absolută.** În exporturile actuale originea comună este deja configurată în colțul stânga-jos.

Analiza a citit comenzile XY de trasare/găurire, excluzând offseturile locale din macro-aperturi. Nu reprezintă simulare CAM completă. Fișierele sunt coerente la nivel de origine și semn; rămân obligatorii verificarea suprapunerii în CAM și verificarea rotațiilor/pinului 1 în portalul JLCPCB după corectarea circuitului. Catalogul identifică piesele; nu am confirmat stocul și acceptarea pentru fiecare dintre cele 31 de poziții la data comenzii.

## 6. Ce înseamnă închiderea auditului

Pentru o nouă revizie trimisă la prototipare trebuie: B1 corectat în schemă și PCB; B2 închis prin alegerea regulator/inductor; B3/B4 rerutate; ERC funcțional și DRC refăcute; verificare BOM/amprente/CPL și reexport coordonat. După acestea poate exista un OK pentru fabricația unui prototip, distinct de validarea de serie. Testele termice, ripple, pornire, sarcini și apă se fac pe placa fizică.

Nu sunt incluse fișiere Gerber „corectate” în acest raport. Pachetul E0 anterior rămâne nerecomandat pentru comandă.

## Surse primare și documentație

- TI SN74HCT14, pinaj: https://www.ti.com/lit/ds/symlink/sn74hct14.pdf
- TI LMR51430, limite și layout: https://www.ti.com/lit/ds/symlink/lmr51430.pdf
- TI SN74LVC1T45: https://www.ti.com/lit/ds/symlink/sn74lvc1t45.pdf
- Diodes AP2112: https://www.diodes.com/datasheet/download/AP2112.pdf
- AOS AOD4184A: https://www.aosmd.com/sites/default/files/res/datasheets/AOD4184A.pdf
- AOS AO3400A: https://www.aosmd.com/sites/default/files/res/datasheets/AO3400A.pdf
- Nexperia BAT54S: https://assets.nexperia.com/documents/data-sheet/BAT54S.pdf
- Arduino Nano: https://content.arduino.cc/assets/Pinout-NANO_latest.pdf
- JLCPCB L1: https://jlcpcb.com/partdetail/Sunlord-SWPA6045S6R8MT/C57254
- JLCPCB L2: https://jlcpcb.com/partdetail/Sunlord-SWPA6045S120MT/C96951
- JLCPCB CPL: https://jlcpcb.com/help/article/pick-place-file-for-pcb-assembly
- Ucamco, polaritatea măștii: https://www.ucamco.com/files/downloads/file_en/209/the-gerber-job-format-specification-technical-manual_en.pdf