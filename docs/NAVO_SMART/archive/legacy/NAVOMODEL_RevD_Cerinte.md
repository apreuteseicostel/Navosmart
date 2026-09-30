# NAVOMODEL Rev.D — D0.1

Pachet CAD nativ pentru prototip,16 septembrie2026. Placă100×100mm, două straturi, cupru2oz, Arduino Nano clasic detașabil și senzor de apă supravegheat.

**Stare:** schema și PCB-ul sunt rutate și verificate digital. Acesta este un candidat de prototip; nu reprezintă o placă validată fizic sau o aprobare pentru producție de serie. Pachetul permite ofertarea și fabricarea primelor exemplare pentru testare. TEST_PLAN.md precizează probele necesare înainte de înghețarea seriei.

## Ce conține

- `cad/NAVOMODEL_RevD.kicad_pro`: proiectul KiCad9, cu schema principală, șase foi funcționale, PCB rutat, reguli și biblioteci locale. Deschide proiectul din acest folder; nu muta doar un singur fișier.
- `docs/Schematic.pdf`: șapte foi A3 cu simboluri electrice, pini, conexiuni și etichete globale; nu sunt imagini generate de AI.
- `docs/PCB.pdf`: cupru față și spate, vedere de sus pentru ambele straturi.
- `docs/Assembly.pdf`: desen de asamblare nativ, cu referințe și pini. Este un desen tehnic2D, nu o fotografie și nu o simulare3D cu componente validate.
- `manufacturing/Gerbers`: Gerber X2, găurire PTH/NPTH și hărți de găurire.
- `manufacturing/BOM.csv`, `Assembly_Extras.csv`, `Positions_SMD.csv`, `Positions_All.csv`: componente, accesorii și poziții de montaj. Fabrica trebuie să adapteze rotațiile la biblioteca mașinii sale.
- `firmware/main.c`, `navomodel.hex`, `optiboot/`: aplicația compilată și bootloaderul, cu sursele și instrucțiunile de programare.
- `docs/PINOUT.md`, `FACTORY_INSTRUCTIONS.md`, `TEST_PLAN.md`: cablare, asamblare, programare și acceptanță. Instrucțiunile pentru fabrică sunt în engleză.
- `verification`: rapoarte native ERC/DRC, comparație de conectivitate și teste ale logicii firmware. `SHA256SUMS.txt` identifică exact fișierele livrate.

## Configurația aplicată

| Funcție | Configurație |
|---|---|
| Baterie | Li-ion4S, maximum16,8V; puterea motorului/ESC rămâne în cablaj separat |
| Far | Un singur far alimentat din baterie prin MOSFET; existent10W, ramură proiectată pentru upgrade30W |
| Poziții | Două lămpi12V/3W, în paralel,6W total; comutate împreună |
| Sonar | Kogger: numai alimentare12V filtrată; datele ocolesc placa |
| Receptor | Ieșire de baterie cu siguranță pentru GR01; nu se conectează la5V |
| Servouri | Trei perechi GND/Vservo/semnal; comenzile trec direct de la H743; placa doar le monitorizează |
| Detectare apă | Sondă pasivă externă, excitație intermitentă, rezistență terminală1MΩ și detectare cablu întrerupt |
| Alarmare | RGB extern și buzzer; alarma de apă rămâne memorată până la confirmare după uscare |
| Control lumini | Canal PWM dedicat: stânga comută pozițiile, dreapta farul; revenire la neutru între comenzi |
| Telemetrie apă | Nu este implementată; alarma acestei revizii este locală |

## Rezultate și limite

ERC:0 încălcări. DRC cu toate severitățile:0 încălcări,0 legături lipsă,0 diferențe schemă–PCB. Testele pe calculator ale funcțiilor reale pentru comanda luminilor și detectarea apei au trecut. Firmware-ul AVR se compilează fără avertismente.

Aceste rezultate nu măsoară încălzirea, rezistența la apă, perturbațiile motorului, curenții reali ai servourilor sau sensibilitatea electrozilor în apa lacului. Alimentarea12V este pentru poziții0,5A și sonar până la0,5A; capacitatea suplimentară a regulatorului oferă rezervă, nu un port suplimentar2A. Placa nu înlocuiește BMS-ul bateriei și nu oprește propulsia când detectează apă.

Nano și modulele cumpărate trebuie verificate mecanic pe primul exemplar. Carcasa, lungimile cablurilor, tipul exact al sondei NTC și compatibilitatea RGB/RGBW se finalizează la integrare. Bugetul inițial de aproximativ£30 nu este confirmat pentru această configurație cu module originale; este necesară o ofertă de fabricație.

Pentru trimitere la ofertare/prototip: folosește întregul pachet și instrucțiunile de fabrică. Pentru serie: acceptă întâi raportul de test al prototipului și emite o revizie înghețată. Nu combina fișierele cu Rev.B/Rev.C sau cu documentele preliminare vechi.