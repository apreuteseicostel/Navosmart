# NAVOMODEL — audit înainte de fabricație

Data: 16 septembrie 2026. Verdict: **HOLD — NU SE TRIMITE LA FABRICAȚIE.**

Auditul a identificat blocaje suficiente pentru respingerea înghețării. Nu este o certificare exhaustivă electrică, mecanică, termică sau de firmware. Nu am modificat originalele și nu am emis Gerbere noi.

## Fișierele identificate și inspectate

Căutarea după titlu a identificat 44 de rezultate NAVOMODEL/NAVO. Cele mai recente pachete relevante sunt din 10 septembrie 2026:

| Pachet | Conținut verificat | Concluzie |
|---|---|---|
| NAVOMODEL_RevC_Engineering_Visuals.zip | 9 fișiere: 5 PNG, PDF, BOM, raport TXT, model JSON | Ultima reprezentare identificată; nu este proiect de fabricație |
| NAVOMODEL_RevB_Final_Complete.zip | 18 fișiere, inclusiv PCB KiCad, .sch, Gerbere, găurire, BOM, firmware Nano și documentație | Mai vechi; denumirea Final nu dovedește validarea |

Rev.C1 din 1 septembrie este cronologic mai veche decât Rev.C din 10 septembrie. Etichetele reviziilor nu constituie singure o ordine sigură.

## Blocaje confirmate din fișiere

1. **Rev.C nu conține .kicad_sch, .kicad_pcb sau Gerbere.** Fișierul Engineering_Check precizează explicit că ERC/DRC KiCad nu a fost rulat și că imaginile nu sunt suficiente pentru comandă.
2. **Rev.B .sch nu este o schemă electrică funcțională.** Conține antet și Text Notes, fără componente și fire. Nu permite ERC sau verificarea corespondenței schemă–PCB.
3. **Rev.C modelul de rutare este incomplet.** JSON conține 31 de elemente plasate și 35 de trasee; nu conține rezistențe sau condensatoare în lista de componente plasate și nici trasee GND. Componentele sunt reprezentate prin dreptunghiuri, fără baza completă de paduri/netlist necesară unui PCB verificabil. Nu poate susține afirmația de PCB complet rutat.
4. **Rev.C BOM este incomplet.** Lipsesc rezistențele, condensatoarele și filtrul FB1 din desen. Unele componente au doar familie/gabarit sau „or equivalent”, fără cod exact. Nu există fișier de poziționare pentru asamblare.
5. **Contradicție la alimentarea sonarului în imaginea Power.** J11 este etichetat +12V filtered, însă firul desenat prin FB1 pornește de la ieșirea U3, etichetată +5V. Aceasta este o eroare în desenul livrat; nu afirm existența unei plăci Rev.C fizice cu această conexiune.
6. **Contradicție la măsurarea bateriei în imaginea Inputs.** Nodul dintre R60/R61 este trasat la terminalul marcat 19 PA3 WATER_SENSE, deși textul spune PA4 BAT_ADC. PA4 este desenat fără această conexiune. Sunt necesare simboluri native și pini verificați.
7. **Schema Outputs nu reprezintă complet MOSFET-urile.** Sunt dreptunghiuri fără terminale G/D/S explicite, iar rezistențele de pull-down sunt descrise textual fără toate conexiunile. Nu este suficientă pentru depanare sau generarea netlistului.
8. **Versiunile schimbă arhitectura.** Rev.B: Nano/ATmega328P, LM2596, 100×75 mm, monitorizare servo pe două fire. Rev.C: ATtiny1616, LMR51430, 100×70 mm, perechi servo 1×3, ieșiri suplimentare și senzor de apă. Gerberele Rev.B nu pot fabrica placa ilustrată în Rev.C.
9. **Firmware Rev.C absent.** Singurul firmware din cele două arhive este pentru Nano. Nu se poate declara compatibil cu ATtiny1616 fără portare, mapare pini și compilare.
10. **ERC/DRC nativ absent în ambele pachete.** Fișierul DRC Rev.B raportează un control propriu al autorouterului, cu limitarea explicită că KiCad nu a fost rulat. Marcajul PASS nu reprezintă validare nativă.

## Alimentare și funcționare — puncte de închis

- LMR51430 este buck, cu duty cycle maxim 98%. La intrare 12 V nu poate garanta ieșire stabilizată de 12 V sub sarcină. Estimarea ideală 0,98×12 = 11,76 V este deja sub 12 V, înainte de pierderi. Trebuie definită tensiunea minimă acceptată de consumatori sau modificată arhitectura.
- Puterea exactă a farului și consumul celorlalte sarcini trebuie fixate. La 30 W, farul singur necesită 2,5 A la 12 V. Inscripția „3 A” a circuitului nu validează termic placa, bobina, conectorii sau cablurile.
- Alimentarea și nivelurile PWM ale GR01 trebuie confirmate în documentația exactei variante înainte de cablare; în ambele pachete recente este prevăzut VBAT, nu 5 V. Această alegere nu a fost certificată independent în auditul de față.
- Conectorii servo trebuie readuși la cerința explicită: perechi 1×3, ordine − / + / semnal, fără a conecta accidental surse BEC diferite. Rev.B nu respectă această configurație.
- Sonarul primește numai alimentare de la placă; datele sale ocolesc placa. ESC/motor rămân pe distribuția separată de putere.
- Componentele de protecție, curentul admisibil, răcirea și punctele de masă necesită verificare pe PCB-ul real, nu pe imagine.

Sursă tehnică pentru limita convertorului: [Texas Instruments LMR51430](https://www.ti.com/product/LMR51430), [datasheet](https://www.ti.com/lit/gpn/LMR51430), consultate la data auditului.

## Observații firmware Rev.B

Inspecție statică, fără compilare sau test hardware:

- Nu există timeout pentru vechimea ultimului impuls RC valid; valorile memorate rămân utilizabile după pierderea impulsurilor.
- NTC întrerupt/scurt este transformat în NAN și nu declanșează avertizarea de temperatură; trebuie prevăzută stare de defect senzor.
- Indicația albastră de cuvă are prioritate vizuală față de temperatura critică și bateria joasă.
- Un impuls de servo peste 1700 µs menține repetat indicația de cuvă; nu este detecție de tranziție și trebuie adaptat sensului fiecărei cuve.
- Modul implicit este pe două canale; cerința anterioară de comandă stânga/dreapta pe un singur canal nu este implicit activă.
- Pragurile bateriei nu au histerezis explicit. Oprirea luminilor nu reprezintă protecție individuală a celulelor sau înlocuitor pentru BMS.

## Verificări efectuate și limite

Am inspectat conținutul integral al ambelor arhive, README/rapoarte/BOM/pinout/firmware, modelul JSON Rev.C, textul .sch și PCB Rev.B, precum și cele trei imagini de schemă Rev.C. Un control geometric restrâns asupra celor 131 de paduri cu net din Rev.B nu a găsit suprapuneri între cercurile înscrise în paduri de neturi diferite. Acest rezultat NU verifică traseele, colțurile padurilor dreptunghiulare, via-urile, clearance-ul, conectivitatea sau potrivirea cu piesele reale.

KiCad CLI nu este disponibil în mediul verificat. Nu am rulat ERC/DRC nativ, DFM la fabrică, simulare termică, compilare firmware sau teste fizice. Nu există dovezi suficiente pentru declararea funcționării.

## Condiții pentru o versiune înghețată

1. O singură schemă nativă completă, cu componente și pini reali, valori și neturi; aceeași arhitectură în firmware, BOM și PCB.
2. Corectarea conexiunilor contradictorii și fixarea bugetului de putere, a conectorilor și alimentării fiecărui echipament.
3. PCB complet din schemă: footprint-uri validate, trasee de alimentare dimensionate, mase, găuri, spațiu pentru conectori și răcire.
4. ERC/DRC fără erori nerezolvate; orice excepție justificată explicit. Verificarea corespondenței schemă–PCB.
5. Pachet unic de fabricație: surse KiCad, schemă PDF, Gerbere și găurire regenerate din aceeași revizie, specificație de fabricație. Pentru asamblare: BOM cu coduri exacte, fișier de poziționare și desen de montaj.
6. Firmware pentru microcontrolerul ales, compilabil, cu binar și instrucțiuni de programare; teste pentru RC, senzori și stări de defect.
7. DFM al producătorului și un lot pilot înainte de producția de serie; măsurarea tensiunilor, încălzirii și zgomotului cu sarcina reală.

**Decizie:** păstrăm pachetele ca referințe, dar nici Rev.B Final, nici Rev.C Engineering Visuals nu sunt eliberate pentru fabricație. Este necesară reconstrucția proiectului CAD complet; redenumirea sau împachetarea fișierelor existente nu rezolvă blocajele.