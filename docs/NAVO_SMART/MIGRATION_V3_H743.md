# NAVO SMART — inventar migrare PCB V2/Nano → H743 + PCB V3
15 octombrie 2026. Inventar și implementare parțială în aplicație; fără validare hardware.

## Baza verificării
- Repository: apreuteseicostel/Navosmart.
- main: b4f4a2d8087b4d0895439d6133518a8ef7c70c4b. Citite toate cele 48 fișiere QML din custom/qml, NavoNanoTelemetry.cc/.h, CustomPlugin.cc/.h, CMakeLists, bridge Lua și firmware Nano relevant.
- PR #20 deschis: fix/g20-advanced-rc-integration-20261005, d5c23e07a2f9a398a90b8c9405891482314d28a1. Verificate Dashboard, G20Settings/Controller, HopperBridge, PreLaunchCheck, NanoTelemetry și SafetyManager. Nu este un audit integral al tuturor diferențelor PR sau al tuturor ramurilor.
- Hardware: NAVO SMART V3 Rev F, 65×40 mm, fără Nano, cu două UBEC externe. Documentația locală de integrare și conectorii V3 au fost consultați.
- Implementarea de mai jos pornește de la b97f8ffa9a7470e2394bab13b7e95fcd3411c066 (PR #20), care include și jurnal, hărți offline și alerte. Fără merge sau test APK pe dispozitiv.

## Arhitectura țintă
Aplicația transmite comenzi și afișează stări prin MAVLink. H743 execută controlul, temporizările și protecțiile locale. PCB V3 păstrează MOSFET-urile și driverul pentru far/poziții, bufferul RGB și condiționarea analogică pentru NTC/apă. V3 nu are procesor, UART propriu sau heartbeat: nu poate fi detectat ca dispozitiv digital independent.

Motorul, cârma și cuvele sunt conectate direct la H743. Camera și sonarul rămân pe transporturile lor LAN. Nu mutăm curentul farului sau al LED-urilor prin GPIO H743.

## Inventar de funcții și controale
| Funcție / control | Situația observată | Ținta V3 / modificare necesară |
|---|---|---|
| Far ON/OFF; acțiunea G20 FAR, implicit L2 | Dashboard.commandNanoLight → comanda MAVLink 31000 → Lua → UART Nano | H743 controlează ieșirea digitală spre J5; V3 comută farul prin Q1. Comenzi explicite ON/OFF, confirmare software și timeout. Nu PWM servo pe intrarea farului. |
| Poziții ON/OFF; acțiunea POZITII | Același bridge, target=2 | H743 → J6 → Q2; 12 V din UBEC extern prin J3/J4. |
| Poziții AUTO | Logica boatActive și comanda sunt în Dashboard | Politica AUTO și starea reținută pe H743; aplicația selectează modul. Definirea exactă a stării „barcă activă” înainte de implementare. |
| Starea luminilor | Decoder NVHEAD/NVPOS există; reprezentările BoatVisual au implicit false, fără legare completă găsită în Dashboard | Legare la telemetria nouă. „Ieșire comandată” nu înseamnă bec aprins fizic: V3 nu măsoară curentul sarcinii. |
| Cuva stângă, dreaptă, ambele; L1/R1 | DO_SET_SERVO 183 către H743, nu către Nano | Păstrăm H743; eliminăm gate-ul Nano și fallback-ul de două secunde în profil V3. |
| Calibrare cuve: ieșiri, PWM deschis/închis, confirmare | Setări persistente în aplicație; ieșiri implicite 9/10, nevalidate pentru barcă | Validare parametri reali SERVOx_FUNCTION și limite; conflict motor/cârmă; calibrare mecanică. Sincronizare cu H743 dacă acesta deține ciclul. |
| Temporizarea închiderii cuvelor | Timer closeTimer în QML, releaseHoldMs=900; retries când legătura lipsește | Ciclul complet executat pe H743, cu limită temporală și prioritate RC. Telefonul trimite cererea, nu asigură închiderea. |
| Stare/animare cuve | leftOpen/rightOpen sunt stări cerute. PR20 adaugă ACK și precizează lipsa confirmării fizice | Păstrăm distincția cerut/acceptat/ieșire PWM/poziție fizică. SERVO_OUTPUT_RAW poate confirma ieșirea, nu mișcarea mecanică. |
| closeHoppers() în Dashboard | Resetează selectedHopper; nu trimite comandă servo | Nu prezenta această funcție drept închidere hardware. Legare la operație reală și idempotentă pe H743 dacă este expusă în UI. |
| START/STOP nădire, selecție cuvă, RTL după eliberare | BaitingController și ActionSequence folosesc HopperBridge | Păstrăm fluxul; eliberarea și închiderea cer confirmare de ciclu, timeout și stare recuperabilă. Nu se presupune succes după simpla trimitere. |
| Temperatura bateriei: TEMP și panoul de diagnostic | NVBATTEMP de la Nano | NTC J9 → buffer V3 → J10 → ADC H743; conversie NTC 10k/B3950, calibrare și validitate separată. |
| Apă în compartiment | NVWATER/NVWFAULT de la Nano | Electrozi J11; GPIO excitație și ADC prin J12. EOL 1 MΩ, măsurare pulsată, stabilizare, filtrare și praguri calibrate. |
| Apă „OK” în UI | Unele etichete afișează OK când waterDetected=false, chiar dacă telemetria lipsește | Necunoscut/indisponibil/defect/uscat/apă detectată distincte. Nu afișăm OK pentru lipsa datelor. |
| Alarme apă/temperatură; HOLD/RTL automat | SafetyManager din aplicație; praguri 45/55°C; temporizare apă 4 s | Decizia primară la bord, pe H743, inclusiv fără aplicație. App afișează și permite confirmarea prevăzută de politică. GPS/HOME invalid trebuie tratat explicit. |
| Protecția farului la baterie slabă/temperatură/NTC defect | Firmware Nano stinge farul la anumite praguri; nu este doar funcție UI | Portare pe H743. Pragurile Nano (ex. 60°C) diferă de aplicație (55°C critic); unificare și calibrare înainte de activare. |
| RGB exterior de stare | Firmware Nano generează culori/stroboscop pentru apă, temperatură, baterie, cuve | H743 serialLED/Lua, conform suportului firmware, către J7.3/J8. Un modul RGB WS2811 3 W la 5 V, driver integrat; priorități și limită de luminozitate. |
| Buzzer local și reset/acquitare alarmă | Firmware Nano are ieșire buzzer și intrare ACK cu apăsare lungă | V3 Rev F nu are mufă/driver dedicat buzzer sau buton ACK. Aceste funcții nu se transferă implicit. Alegere: alarmă pe G20 + RGB; buzzer extern H743 numai cu interfață compatibilă. |
| Baterie %, tensiune/curent | Dashboard folosește deja vehicle.batteries; Nano publică separat NVBATV | O singură sursă principală H743 BATTERY_STATUS/SYS_STATUS, monitor calibrat. V3 nu adaugă măsurare baterie. |
| Monitor PWM cârmă/cuve NVHOPL/NVHOPR/NVRUD | Nano citește impulsuri și le publică; decoderul există | Telemetrie ieșiri H743; eliminăm citirea duplicată Nano. Nu este feedback fizic de poziție. |
| NANO ON/OFF / ONLINE/OFFLINE | Dashboard și pagină diagnostic | Înlocuire cu stări separate H743 conectat, serviciu V3 activ, temperatură validă, sondă apă validă. Fără indicator fals „PCB V3 conectat”. |
| Pre-launch Nano (PR20) | nanoReady contribuie la avertismente, nu la navigationReady | Eliminare verificare Nano în V3. Verificări reale pe funcții configurate; senzor absent și senzor defect se disting. |
| G20 Advanced, RC_CHANNELS | PR20 are controller opt-in și protecție la reconectare; main are versiune mai veche | Păstrăm varianta avansată, implicit oprită. Controlul critic și fizic trebuie să funcționeze G20→GR01→H743 fără Android. Evităm executarea dublă prin RC direct și prin app. |
| RTL/HOME, MANUAL/HOLD/AUTO, pilotaj, ancoră | Funcții H743, nu Nano | Nu necesită portarea de pe V2; regresie obligatorie după migrarea comenzilor și alarmelor. |
| Sonar, temperatura apei, cameră, hartă, scanare, batimetrie, puncte/replay | Nu am identificat dependență directă Nano în aceste module din main | Se păstrează. Temperatura sonarului nu înlocuiește NTC baterie. Acțiunile live rămân blocate în replay. |

## Probleme concrete care trebuie rezolvate la migrare
1. NavoNanoTelemetry are un singur lastUpdateMs pentru toate cele zece valori. Orice mesaj cunoscut menține connected=true, inclusiv dacă temperatura sau apa nu mai sosesc. Noul model cere validitate și vârstă per semnal, plus heartbeat/version/capabilities pentru serviciul H743.
2. Lua vechi răspunde ACK după trimiterea textului UART, fără confirmarea execuției Nano. Nu reutilizăm acel ACK drept dovadă de acționare.
3. Comanda TOGGLE poate avea efect dublu la repetare. UI va determina starea dorită și va transmite SET ON/OFF; idempotent, corelat cu un rezultat și o stare publicată.
4. Apa și temperatura sunt legate prin același gate în SafetyManager. Lipsa unui senzor poate împiedica evaluarea celuilalt; timerul de apă poate continua după pierderea telemetriei. Validarea și politica trebuie separate pe senzori.
5. NavoHopperBridge trimite comenzi pentru ambele cuve cu același tip MAVLink; ACK nu identifică sigur ieșirea. PR20 recunoaște această limitare. Serviciul de ciclu trebuie să aibă identificator și progres propriu.
6. Închiderea cuvelor nu trebuie să depindă de supraviețuirea unui Timer Android. Oprirea aplicației, pierderea linkului și reboot-ul H743 cer teste distincte.
7. Resetarea alarmei nu trebuie să ascundă apă încă prezentă sau o sondă defectă. Definim separat confirmarea notificării și ștergerea stării memorate.
8. V3 nu măsoară bec ars, servo blocat, obstacol sau curent individual de motor. Nu marcăm aceste funcții ca existente doar prin schimbarea UI.

## Module de lucru
- NavoNanoTelemetry.cc/.h → model neutru NavoHardwareTelemetry, cu profil V2 legacy și V3 H743; contract de mesaje documentat. Nu redenumire cosmetică.
- NavoDashboard.qml → eliminare gate Nano pentru profil V3, legare senzori/stări noi, rutare lumini, diagnostic și pre-launch.
- NavoHopperBridge.qml + NavoBaitingController.qml + NavoBaitingPanel.qml + NavoActionSequence.qml → comenzi de ciclu, confirmări, retry sigur, oprire/recuperare.
- NavoSafetyManager.qml + NavoFailsafeController.qml → oglindirea deciziei de la bord; alarme pe senzori independenți; fără două autorități contradictorii.
- NavoPreLaunchCheck.qml din PR20 → verificări pe capabilități, fără Nano obligatoriu în profil V3.
- NavoG20Controller.qml / Settings din PR20 → păstrare opt-in și arbitraj RC/app.
- NavoBoatStatus.qml / NavoBoatVisual.qml / NavoSafetyCard.qml → conectare la stări reale; necunoscut separat de OK.
- CustomPlugin.cc, CMakeLists, resurse QML și icon nano.svg → înregistrarea noului model și curățare controlată.
- ardupilot/scripts/navo_nano_bridge.lua → rămâne doar pentru V2; serviciu nou navo_v3_io.lua propus pentru V3.
- firmware/NAVOMODEL_Arduino → arhivare ca V2, nu ștergere înainte de închiderea migrării. Testele vechi se păstrează pentru compatibilitate.

## Contract propus, încă neimplementat
Serviciul H743 publică: versiune/profil, capabilități, temperatură și validitate, apă brută/stare/defect, stare comandată far/poziții, mod lumini, starea ciclului cuvelor și alarme memorate. Fiecare valoare primește timp de actualizare. La deconectare devine necunoscută; un mesaj de lumină nu prelungește validitatea temperaturii.

Păstrarea temporară a numelor NVBATTEMP/NVWATER/NVHEAD este posibilă pentru compatibilitate, dar cu identificarea explicită a profilului și fără vechiul flag global connected. Bateria și ieșirile servo folosesc telemetria standard unde este disponibilă. Alegerea finală a comenzilor și mesajelor se verifică pe versiunea Rover instalată; nu se livrează acum parametri gata de încărcat.

## Corelare cu V3
J5 far, J6 poziții, J7 comandă RGB și alimentare externă 5 V, J8 LED RGB, J9 NTC, J10 ADC temperatură +3V3, J11 electrozi, J12 excitație/ADC apă. Padurile H743 propuse S6/S7/S8/S13, RSSI/PC5 și CU2/PA7 nu sunt confirmate libere. Nu confundăm numărul canalului RC cu numărul ieșirii servo sau GPIO.

Sonda V3 are altă interfață analogică față de firmware Nano; nu copiem pragurile ADC 10-bit, referința 5 V, formula NTC sau întârzierea Nano de 10 ms. Pentru circuitul V3 documentația propune inițial circa 100 ms de stabilizare pentru apă, apoi calibrare reală.

ArduPilot oferă scripting, control GPIO, exemple de citire analogică și serialLED, însă disponibilitatea depinde de firmware/build și de pinii configurați. Dacă API-ul necesar lipsește, se adaptează build-ul sau se folosește suportul nativ corespunzător; nu presupunem că simpla conectare produce telemetrie.

## Ordine de implementare și acceptanță
1. Contract și profil hardware V3; inventar parametri H743 fără suprascrierea configurației reale. Teste: lipsă mesaj, mesaje parțiale, schimbare vehicul, reconectare.
2. Serviciu H743 pentru senzori și lumini; teste cu tensiuni/rezistențe cunoscute, sondă întreruptă/scurt și pornire separată UBEC/H743. Fără el UI nu poate primi valori reale.
3. Model telemetrie și Dashboard/pre-launch; eliminarea dependenței Nano numai în V3. Datele lipsă nu apar ca OK.
4. Cuve: ciclu local H743, calibrare, identificator de comandă, rezultat și timeout. Teste cu servouri fără sarcină, link întrerupt în timpul ciclului, comandă repetată, reboot, prioritate pilot.
5. Alarme/RGB/RC: politica la bord, temperaturi/praguri unificate; teste fără aplicație și cu GPS/HOME invalid. Buzzerul rămâne funcție neechipată până la alegerea interfeței.
6. Regresie Android + simulator/SITL, apoi banc H743+PCB V3, apoi barcă. Nu se face merge doar pentru că build-ul este verde.

## Surse
Cod main: https://github.com/apreuteseicostel/Navosmart/tree/b4f4a2d8087b4d0895439d6133518a8ef7c70c4b
Cod PR20: https://github.com/apreuteseicostel/Navosmart/tree/d5c23e07a2f9a398a90b8c9405891482314d28a1
Scripting: https://ardupilot.org/dev/docs/common-lua-scripts.html
Exemplu ADC/GPIO: https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_Scripting/examples/analog_input_and_GPIO.lua
Comenzi servo: https://ardupilot.org/dev/docs/mavlink-move-servo.html


## Implementat la 15 octombrie 2026 — etapa aplicației
- Selector persistent V2/V3 în Siguranță → Cuve & siguranță hardware; schimbarea necesită deconectare și invalidează confirmarea calibrării. V2 rămâne implicit pentru compatibilitatea instalațiilor existente.
- Profilul V3 elimină condiționarea cuvelor de Nano și așteptarea de două secunde. Conexiunea H743 și calibrarea rămân obligatorii.
- Validitate independentă pentru temperatură și apă, cu expirare la 2,5 secunde pe ceas monoton. Pentru apă sunt obligatorii atât măsurarea, cât și starea de defect recente.
- Temperatura expirată devine NaN. Diagnostic apă indisponibil în loc de fals OK. Pre-launch folosește validitatea ambilor senzori și eticheta profilului.
- Alarmele evaluează independent apa și temperatura. Pierderea datelor întrerupe confirmarea în curs a apei; o alarmă deja confirmată se păstrează până la o citire validă uscată. Schimbarea vehiculului șterge starea veche.
- Alertele audio folosesc validitatea fiecărui senzor. Testele existente pentru replay și deduplicare sunt păstrate.
- Profilul V3 refuză comanda UART Nano 31000. Luminile V3 NU sunt implementate încă; UI explică indisponibilitatea. Replay și pierderea conexiunii refuză și comenzile legacy.

### Contract de recepție V3 rezervat pentru integrare
Mesaje MAVLink NAMED_VALUE_FLOAT de la sysid-ul vehiculului activ și componenta autopilot 1:

| Nume | Semnificație |
|---|---|
| NV3VER | Heartbeat serviciu, valoare exact 1 pentru această versiune de protocol; nu reprezintă detectarea fizică a PCB |
| NV3TEMP | Temperatură °C; NaN sau <= -1000 invalidează măsurarea |
| NV3WATER | 0 uscat / 1 ud; alte valori invalidează măsurarea |
| NV3WFAULT | 0 fără defect / 1 defect; alte valori invalidează măsurarea |

Mesajele legacy NV* nu activează V3. Datele senzorilor nu înlocuiesc heartbeat-ul NV3VER. Acest commit adaugă receptorul, **nu un serviciu de bord care emite aceste mesaje**. Protocolul rămâne de verificat cu firmware-ul instalat.

### Limite și următorul pas obligatoriu
Temporizarea închiderii cuvelor rămâne în aplicație. Nu există încă garanție de închidere la oprirea telefonului; mutarea ciclului pe H743 este o etapă distinctă obligatorie. Butonul closeHoppers existent schimbă numai selecția vizuală; nu este prezentat drept închidere fizică.

Serviciul H743 trebuie să implementeze citirea ADC, excitația sondei, conversia NTC Rev F, lumini, RGB, cicluri locale cuve și protecții locale. Nu încărca parametri GPIO/servo propuși fără exportul .param, verificarea firmware-ului și a pinilor ocupați. Nu au fost introduse în acest commit atribuiri de pini sau conversii analogice presupuse.

Validare locală: 56 scenarii audit, 7 G20, 20 rute și 10 steering/bottom; teste Qt 6.8.3 pentru safety, alerte și importul modulului. Testele C++ ale parserului real sunt adăugate în CI cu transport MAVLink simulat; compilarea locală a lor este blocată de lipsa Qt development, instalarea apt fiind indisponibilă în mediu. Build-ul APK și acceptanța fizică nu sunt confirmate.


## Actualizare: serviciul V3 și integrarea comenzilor
Etapa de mai sus descrie primul commit. Ulterior au fost adăugate serviciul Lua, conversia NTC configurabilă, citirea pulsată a apei, lumini, RGB de stare și cicluri cuve temporizate la bord. Aplicația V3 folosește acum 31001 și capabilități cu expirare; nu mai folosește temporizarea locală pentru cuve. Luminile sunt disponibile numai când serviciul configurat raportează capabilitatea și stări proaspete. Butonul closeHoppers cere închidere la bord în V3.

Configurația livrată rămâne dezactivată și fără pini presupuşi. Detalii și limite actualizate: `ardupilot/NAVO_V3_SERVICE.md`. Nu este încă o configurație validată a bărcii. Protecțiile autonome de navigație, configurarea fizică și testarea pe firmware-ul instalat rămân deschise.
