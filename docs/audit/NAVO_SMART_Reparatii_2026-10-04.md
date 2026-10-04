# NAVO SMART — reparații și validare după audit, 4 octombrie 2026

Repository: [apreuteseicostel/Navosmart](https://github.com/apreuteseicostel/Navosmart). Snapshot: 2026-10-04T18:05:25.567Z. Cod main: `b52a315b41cd0149aec9d852a6941d64d600dc91`; tree: `aaed7a6770e6561b63ea51bd2a37f0ba816314e7`.

## Rezultat și limite

Reparațiile și procesarea nativă Kogger sunt integrate în main prin PR #16 (merge b52a315). PR #19 este marcat integrat prin aceeași ancestrie, fără merge separat al variantei comune. Main are exact arborele validat de Android #784. Verificările Core #65 și Display #37 pe main au trecut; rebuild-ul Android #785 pe main este încă în curs. Este un candidat software utilizabil și verificat automat, cu acceptanța hardware restantă.

Acest raport separă corecțiile implementate, testele automate și acceptanța fizică. APK-ul și testele software nu confirmă cursa servo-urilor, conexiunile electrice, comportamentul pe apă sau toate funcțiile opționale. Modulele care au cod, dar nu sunt conectate la fluxul aplicației, sunt identificate explicit.

## Build-uri și probe

| Verificare | Sursă | Rezultat |
|---|---|---|
| [Android #784](https://github.com/apreuteseicostel/Navosmart/actions/runs/37218972880) | a0e065f, arbore identic cu main | Verde; ARM64/x86_64, toate cele 11 pagini, meniu/X PRO |
| [Core #64](https://github.com/apreuteseicostel/Navosmart/actions/runs/37218972814) | a0e065f | Verde; firmware/Lua/persistență și 31 regresii |
| [Display #36](https://github.com/apreuteseicostel/Navosmart/actions/runs/37218972945) | a0e065f | Verde; Canvas, wiring/Popup și gesturi 3D |
| [Replay #50](https://github.com/apreuteseicostel/Navosmart/actions/runs/37218972845) | a0e065f | Verde; pipeline real și izolare |
| [Core main #65](https://github.com/apreuteseicostel/Navosmart/actions/runs/37221963978) | b52a315 | Verde |
| [Display main #37](https://github.com/apreuteseicostel/Navosmart/actions/runs/37221964030) | b52a315 | Verde |
| [Android main #785](https://github.com/apreuteseicostel/Navosmart/actions/runs/37221963970) | b52a315 | În curs; nu este încă declarat verde |
| [Android comun #783](https://github.com/apreuteseicostel/Navosmart/actions/runs/37218968113) | 5f36409 | Compilarea ambelor ABI a trecut; smoke eșuat la prima HARTA. Backend-ul comun nu expune replayMode, cerut de noile binding-uri. Main folosește implementarea nativă validată |

- 31 de scenarii de regresie: geometrie și progres misiune, schimbare baltă și checkpoint refuzat, nădire/viteză/derivă, timeout Nano, PWM/ieșiri, închidere la reconectare, fish/range/offset, replay versus date live, editare și pregătire/Resume/START de misiuni live.
- Nano ATmega328P/16 MHz compilat cu Arduino AVR core real: **9.978 bytes flash și 466 bytes RAM statică**. Stiva la runtime nu este inclusă.
- Scriptul H743 Lua real, cu UART/MAVLink simulate: cadre fragmentate, checksum, câmpuri invalide, overflow și recuperare, limitele comenzilor.
- Persistență Qt reală: migrare, scrieri refuzate, rollback, delete/save/assign și citire dintr-un proces independent.
- Qt/QML real: coordinatorul din Dashboard are dependențele conectate; Popup-ul sonar simplu și X sunt în viewport; Canvas-ul PRO păstrează peak/filter/cache/crop; handler-ele 3D și calculele camerei se încarcă și păstrează limitele.
- Replay #50, pe a0e065f: **15.423 coloane CHART de 5.000 samples**, 15.266 epochs cu GPS original, 14.486 rezultate de adâncime, șase tile-uri native. Mapping → persistence reload → HD: 890 celule de grilă, 127 celule HD și 148 segmente de contur. Sunt rezultate ale înregistrării, nu măsurători noi în teren.
- Testele folosesc și TCP real pe localhost, replay din fișier, GPS fix/loss gating, pause/EOF/stop, salvarea explicită ca baltă separată și izolarea rezultatelor queued după reset.
- Sonar PRO: 240 de coloane reale, palete zi/noapte, landscape/portrait, asociere întârziată a fundului, meniu/X. Harta este simulată în testul izolat al componentei.
- Ultima coloană parțială de 200 samples din fixture rămâne pending până la următoarea limită de coloană; nu este declarată coloană completă.
- Capturile Android #765/#766 și toate paginile #774 au fost inspectate și sunt curate în acele rulări. #773, deși verde inițial, avea un avertisment de ancorare și antetul peste PRO; acestea au fost reparate, iar smoke-ul extins le respinge.
Capturile finale #784 sunt publicate în artefacte și smoke-ul a verificat controalele și logcat-ul. Revizia manuală a imaginilor finale este blocată de mediul local offline; nu este declarată efectuată. Codul, binarele CI și raportul rămân disponibile pe GitHub.

## Firmware și cuve independente de Nano

Firmware.cpp avea un literal neterminat, o directivă coruptă și implementări duplicate. Există acum o singură inițializare/buclă compilabilă, păstrând funcțiile de senzori, lumini, alarmă și monitorizare servo. Parserul NAVOCMD validează versiunea, checksum-ul XOR, operația și toate câmpurile înainte de modificarea stării. Bufferul UART Nano are 64 bytes; un cadru prea lung este abandonat până la newline și următorul cadru se poate recupera. Lua limitează citirea la 256 bytes/update și aplică aceleași reguli de recuperare și validare.

Timeout-ul ales este **2.000 ms**, verificat periodic. Fără telemetrie Nano validă, după timeout devin disponibile comenzile solicitate de deschidere, dacă H743 este conectat și calibrarea este validă. **Timeout-ul nu deschide automat cuvele.** Revenirea telemetriei și schimbarea/pierderea vehiculului recalculează fallback-ul.

| Funcție | Comportament reparat |
|---|---|
| updateNanoHopperAvailability | Folosește lastUpdateMs și timpul complet în ms; acoperă Nano absent de la conectare sau dispărut ulterior |
| canSendServo / setServo | Cer H743, calibrare, interfață de comandă, ieșire 1–16 și PWM 900–2100 µs; închiderea nu depinde de Nano |
| release | Validează ambele ieșiri și toate valorile înaintea primei comenzi; ieșirile celor două cuve trebuie să fie diferite |
| closePending / timer | Păstrează starea comandată și reîncearcă închiderea după reconectarea H743; pierderea Nano nu blochează închiderea |
| parse / handle_gcs_commands / update Lua | Resping checksum/câmpuri/parametri invalizi, numere nefinite și overflow; nu rotunjesc input invalid într-o comandă validă |

Componenta QML și timerul real au trecut local deschiderea, pierderea Nano și H743, păstrarea stării, apoi închiderea ambelor cuve la reconectare, cu vehicul simulat. Indicatorii reprezintă comenzi trimise; poziția mecanică și ACK/rejecția autopilotului necesită test pe barcă. Firmware-ul nu a fost flash-uit în această intervenție. Watchdog-ul rămâne configurat conform Config.h, fără activare hardware presupusă.

## Replay izolat

| Cale | Protecție |
|---|---|
| Fish detector / recordLiveFishDetection | Nu scriu echo replay sau evenimente întârziate în colecția live; cer link și GPS valide |
| PRO captureGeoChart | Nu atașează GPS-ul vehiculului live la o coloană înregistrată |
| requireActiveLakeForPointSave | Refuză salvarea punctelor replay în balta live activă |
| Worker Dataset/bottom/surface | Generația sesiunii împiedică rezultate queued vechi să modifice Dataset/tile-uri după clear/rollover |
| Hartă / 3D | Ascund fish/puncte/waypoints/traseu/marker live în redarea înregistrată și folosesc modelele replay |
| PRO split-map fără GPS înregistrat | Nu înlocuiește poziția lipsă cu GPS-ul bărcii live și nu afișează ruta misiunii live |
| NavoMap | Refuză desenarea și commit-ul întârziat al geometriei, alegerea punctului și dialogurile de editare |
| Coordinator / Dashboard | Refuză geometrie, pregătire/Resume, UPLOAD/START, navigare și nădire live din replay |
| Autosave | Timerul catalogului live este suspendat în replay; progresul legitim al unei misiuni live deja active rămâne separat |
| Salvare explicită | Creează o baltă distinctă, cu proveniență replay și stare COMPLETE, fără misiune autopilot |

Comenzile de închidere a cuvelor, HOLD/RTL și progresul unei misiuni live existente nu sunt blocate global. Regresiile verifică și cazul cu un vehicul live conectat în timpul replay-ului.

## Durabilitatea ștergerii

Lacurile și sesiunile folosesc un singur catalog JSON, navo/catalogV1, cu atomic sync QSettings. Cheile legacy se citesc numai dacă noul catalog lipsește, pentru migrare. Un lac șters nu este reimportat din vechile chei după migrare.

| Funcție | Comportament verificat |
|---|---|
| load | Încarcă catalogul comun; migrează legacy o singură dată |
| saveCatalog | Salvează ambele colecții împreună, verifică sync și restaurează inclusiv cache-ul QSettings la eșec |
| saveLake / saveLakeState | Restaurează memoria și nu emit fals succes dacă scrierea eșuează |
| deleteLake | Șterge lacul și sesiunile asociate împreună; false și rollback la eșec; semnale numai după succes |
| save/deleteBathymetrySession / assignSessionToLake | Propagă eroarea și restaurează colecțiile/asocierea |
| clearActiveLake | Elimină starea restaurată și colecțiile active după ștergere reușită |

Citirea din proces separat dovedește că verificarea nu folosește doar cache-ul aceluiași proces. Testele sunt pe backend-ul Qt real și fișier INI; întreruperea fizică a alimentării și durabilitatea pe dispozitiv rămân acceptanță hardware. Colecțiile globale legacy nu sunt declarate complet eliminate prin această reparație.

## Interfață și fluiditate

Au fost reparate dependențele Dashboard prin referințe root explicite: persistență, fish store, mapping, controllerii hărții, hopper bridge, Ethernet sonar și punctele 3D. NavoSonarFullScreen separă overlay-ul de ColumnLayout și ține mesajul fără date în zona ecogramei. Fullscreen PRO este deasupra Dashboard, cu antet/sidebar/PiP ascunse; meniul este ancorat la bara de telemetrie. Navigarea Android derulează un buton parțial vizibil înainte de tap.

chartRawByteCount numeric elimină citirea .length pe QByteArray. Prima pornire setează unități metrice numai pentru preferințele lipsă, păstrând alegerile existente. Selecția G20 AUTO nu pornește o misiune pentru un vehicul armat; START rămâne explicit.

NavoBoatVisual util din PR #10 a fost recuperat și integrat în hartă, compas și cuve. Componenta reală a trecut încărcare/randare/resize, lumini, cârmă și stări ale cuvelor. Hărțile standalone folosesc FlightMap fără contextul vechi FlyView.

Rotația/zoom-ul 3D reaplicau valorile cumulative la fiecare eveniment. Camera folosește acum poziția de la începutul gestului și activeTranslation/activeScale, cu validare și limite. Testul Qt încarcă handler-ele reale și execută funcțiile camerei pe secvențe cumulative; nu simulează un gest fizic pe G20.

Sonar PRO păstrează toate cele 5.000 samples ale fiecărei coloane din istoricul limitat la 240. Pentru afișare construiește peak envelopes per rând de pixel într-un cache bounded și desenează împreună rânduri de aceeași culoare. Gain/floor reutilizează vârfurile, fără rescanarea datelor brute; filtrul și scara fizică invalidează geometria. HD oprit nu mai recalculează grila IDW.

| Măsurătoare controlată locală | Înainte | După |
|---|---:|---:|
| Coloană nouă, mediană | 1.234,92 ms | 11,81 ms |
| Coloană nouă, p95 | 1.341,50 ms | 14,76 ms |
| Coloană nouă, maxim | 1.344,31 ms | 20,39 ms |
| Gain, prima variantă cache versus cache în două etape | 368,81 ms | 25,44 ms |

Comparație secvențială pe același Qt 6.4.2 software, 960×540, 240×5.000 samples sintetice dense, 24 redesenări după încălzire: mediana este aproximativ 105× mai mică. Sunt timpi Canvas, **nu FPS măsurat al întregii aplicații Android/G20**. Prima afișare și schimbarea scalei/filtrului necesită recalculare. Cache-ul pentru 240×540 are aproximativ 1,17 MB pentru cele două tablouri Float32 și Uint8, separat de istoricul brut și overhead.

Înregistrarea reală a avut mediane 12,68 ms (#44), 13,09 ms (#49) și **21,87 ms în ultimul #50**, cu p95 27,99 ms, maxim 35,00 ms și gain 38,29 ms în #50. Runnerii diferiți nu formează o comparație controlată și valorile nu garantează 60 FPS pe G20. Regresiile pentru peak, filtre, crop și păstrarea samples au trecut în toate aceste rulări.

Build-ul folosește QGC_USE_CACHE oferit de QGroundControl v5.0.7, ccache limitat la 2 GiB și statistici CI. Android #784 a confirmat configurarea și folosirea ccache: prima rulare este cold, cu zero hits și aproximativ 0,42 GB stocați din limita de 2 GiB. Accelerarea unui rebuild cu cache cald nu a fost încă măsurată.

## Îmbunătățiri prioritare

| Prioritate | Lucru rămas | Dovadă / criteriu |
|---|---|---|
| 1 | Profilare G20, sonar/GPS real, minimum 60 minute | Măsurați p95 frame/input, cold-start, memoria și reconnect. Cadrele Choreographer omise la pornirea emulatorului nu sunt steady-state FPS |
| 2 | Checkpoint numai la modificări și scriere în afara UI | Timerul actual salvează la 5 s cu baltă activă, inclusiv idle în afara replay-ului. Qt/INI, 8 scrieri: mediane 48,36 ms/5k samples, 133,40 ms/15k, 439,05 ms/50k; maxim 486,17 ms/50k. Păstrați atomicitatea, rollback-ul și ordinea delete/save |
| 3 | Model incremental pentru samples și backpressure/memorie | Mapping copiază rawSamples la fiecare sample; PRO are și coadă raw bounded. Măsurați latența și memoria fără pierderea coloanelor procesate |
| 4 | Renderer direct al tile-urilor native și HD în worker | Tile-urile se generează; harta păstrează overlay-ul NAVO funcțional derivat din samples. Comparați poziția/scara/imaginea înainte de înlocuire |
| 5 | Flux instalat complet KLF → PRO → GPS/hartă → HD/3D → save/restart | Ambele orientări, file provider Android, fixture cu date și validare pe G20; smoke-ul fără hardware nu acoperă aceste interacțiuni |
| 6 | Reutilizarea rendererului PRO în sonar legacy | Popup-ul simplu rămâne separat; migrarea trebuie să păstreze paletele, scara, meniul și datele brute |

## PR-uri și branch-uri

| PR | Acțiune |
|---|---|
| #3 | Închis: conținut ajuns în main prin #4; bază istorică |
| #5 | Închis: sonar vechi înlocuit, conflicte și eroare QML; funcțiile utile sunt în PRO |
| #6 | Închis: mobile UI/HD recuperate prin #7/#8 și integrările următoare |
| #10 | Închis după recuperarea componentei de barcă în #17 |
| #15 | Închis: meniu/scală/X/map realizate în PRO actual; branch vechi conflictual |
| #17 | Integrat: firmware/Nano/cuve/persistență/replay și reparații comune |
| #18 | Integrat: CHART byte count, layout, emulator/first-run și regresii runtime |
| #19 | Integrat prin PR #16, fără merge separat al variantei comune; GitHub îl marchează merged |
| #16 | Integrat în main: b52a315; source tree identic cu cel validat de #784 |

Branch-urile vechi sunt păstrate. Un head divergent nu justifică integrarea în bloc a implementărilor înlocuite. Nu mai există PR-uri deschise după această integrare.

Cele 31 branch-uri de aplicație au fost comparate cu main prin API GitHub (branch head → main). «Inclus» înseamnă strămoș în istoric; nu certificare hardware. «Divergent» înseamnă că branch-ul are commits proprii istorice; auditul le-a evaluat și nu recomandă merge integral al variantelor înlocuite.

| Branch | Head | Stare față de main |
|---|---|---|
| audit/full-integration-23-sep | f0ac077 | Inclus în istoric; nu necesită merge suplimentar |
| docs/navo-smart-reference | cab6bf2 | Inclus în istoric; nu necesită merge suplimentar |
| feature/area-scan-bathymetry-resume | 52a0d00 | Inclus în istoric; nu necesită merge suplimentar |
| feature/bathymetry-3d | 176f888 | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/bathymetry-hd-overlay-24-sep | 79dc716 | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/ethernet-camera-sonar | 2c48d4b | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/ethernet-v1-preparation | cb4a949 | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/g20-controls | 6b0caff | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/kogger-native-dataset-adapter-20261002 | a0e065f | Inclus în istoric; nu necesită merge suplimentar |
| feature/kogger-sonar-final | f196900 | Inclus în istoric; nu necesită merge suplimentar |
| feature/my-lakes-persistence | 758840c | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/navo-smart-pro | 7dc99c3 | Divergent istoric; păstrat, fără merge integral recomandat |
| feature/sonar-pro-fullscreen | 3b14258 | Inclus în istoric; nu necesită merge suplimentar |
| feature/sonar-pro-network-02-oct | 52a3406 | Inclus în istoric; nu necesită merge suplimentar |
| feature/unified-navosmart-integration | 0c51e5f | Inclus în istoric; nu necesită merge suplimentar |
| firmware-h743-uart | d004c25 | Divergent istoric; păstrat, fără merge integral recomandat |
| fix/android-runtime-review-04-oct | 62cc141 | Inclus în istoric; nu necesită merge suplimentar |
| fix/main-audit-04-oct | 58c060f | Inclus în istoric; nu necesită merge suplimentar |
| fix/sonar-display-performance-04-oct | 5f36409 | Inclus în istoric; nu necesită merge suplimentar |
| fix/sonar-pro-overlay-controls-20261002 | d4c916f | Divergent istoric; păstrat, fără merge integral recomandat |
| fix/ui-map-safety-settings-25-sep | d78d31b | Inclus în istoric; nu necesită merge suplimentar |
| fix/ui-screenshots-28-sep | 827af24 | Inclus în istoric; nu necesită merge suplimentar |
| integration/final-recovery-28-sep | 1b34246 | Inclus în istoric; nu necesită merge suplimentar |
| integration/recover-missing-branches-25-sep | d36d1da | Divergent istoric; păstrat, fără merge integral recomandat |
| integration/ui-recovery-24-sep | 4f2171b | Divergent istoric; păstrat, fără merge integral recomandat |
| kogger-live-transport | e2563a4 | Divergent istoric; păstrat, fără merge integral recomandat |
| main | b52a315 | Main actual |
| nano-telemetry-ui | 0db3563 | Divergent istoric; păstrat, fără merge integral recomandat |
| ui/g20-polish-30-sep | b6c1b2a | Inclus în istoric; nu necesită merge suplimentar |
| ui/mobile-map-layout-24-sep | 468b44c | Divergent istoric; păstrat, fără merge integral recomandat |
| ui/sonar-2d-pro-24-sep | ba4dd7b | Divergent istoric; păstrat, fără merge integral recomandat |

Acest raport este publicat separat pe audit/report-repairs-04-oct, pornind din main, cu modificări numai de documentație. Astfel sunt 32 branch-uri după publicarea raportului; branch-ul raportului nu schimbă aplicația.


## Inventar QML — 49 componente

„Cod prezent” nu înseamnă că fiecare funcție opțională este terminată și certificată pe barcă. Inventarul liniei complete native:

| Componentă | Rol și stare |
|---|---|
| NavoDashboard | Pagini/controlleri/telemetrie; binding-uri, timeout Nano, replay și fullscreen reparate; verificări Android descrise mai sus |
| NavoMap | FlightMap/GPS/HD/ruler/desen; replay separat și editare blocată; acceptanță cu date/G20 restantă |
| NavoActualTrack | Breadcrumb live; ascuns în replay; GPS real restant |
| NavoHeadingCompass | Compas mic/mare și BoatVisual verificat Qt; comparare G20 restantă |
| NavoBoatVisual | Barcă/servo/lumini/cârmă; recuperat, randare/resize Qt verificate |
| NavoBoatStatus | Indicatori de comenzi; nu confirmă poziția mecanică |
| NavoModeButton | Selector mod; confirmare pe H743 necesară |
| NavoTelemetryCard | Afișare Nano/G20; sursa fizică nevalidată |
| NavoWaypointEditor | Editare/nume; flow instalat/restart restant |
| NavoWaypointDetails | Detalii/navigare/nădire; navigare reală restantă |
| NavoWaypointMapOverlay | Marcaje; ascunse în replay; poziționare cu date pe APK restantă |
| NavoFishingSpots | Colecție de puncte/checkpoint; mutații UI/restart restante |
| NavoMyLakes | Add/rename/delete/load/Resume; backend atomic verificat; flow UI pe dispozitiv restant |
| NavoScanCoordinator | Sesiune/autosave/progres; wiring real și replay gate verificate |
| NavoAreaScan | Dreptunghi/poligon/culoare/resume; geometrii invalide respinse; plafon 500 puncte misiune |
| NavoAreaScanOverlay | Preview/progres live; ascuns în replay; H743 restant |
| NavoAreaDrawOverlay | Helper de desen separat; există și desenul din Map, duplicarea trebuie clarificată |
| NavoMissionUploader | Upload QGC/ACK/count/timeout; flow fizic upload/start/reached/Resume restant |
| NavoBaitingController | Approach/settle/release/exit/RTL; viteza necunoscută/deriva/rejecția testate; actuație reală restantă |
| NavoBaitingPanel | UI/setări; hopper bridge conectat; replay nu oferă puncte live |
| NavoHopperBridge | Set-servo/închidere temporizată; independent Nano după timeout și retry H743; ACK/cursă fizică restante |
| NavoActionSequence | Helper fără instanțiere Dashboard dovedită; nu funcție activă livrată |
| NavoDigitalAnchor | Instanțiat, fără apel engage Dashboard identificat; staționare GPS nelivrată complet |
| NavoEnergyGuard | Instanțiat, necalibrat implicit; apel/gate Dashboard complet nedovedit |
| NavoFailsafeController | Link/GPS/HOLD/RTL; timpi/link testați; parametri fizici H743 restanți |
| NavoFailsafePanel | UI failsafe; verificare orientări/scroll pe G20 restantă |
| NavoSafetyManager | Apă/NTC/HOLD/RTL; fault/praguri fizice restante |
| NavoSafetyCard | Stare senzori; răspuns hardware restant |
| NavoSonarEthernet | Transport/decoder/replay/native; TCP localhost/fișier/GPS gating verificate, Kogger live restant |
| NavoSonarPro | Cache fizic/scală/echo/palete/meniu/X/replay; componentă reală și smoke, acceptanță live G20 restantă |
| NavoSonarFullScreen | Popup legacy layout/X reparate și randate Qt; renderer separat |
| NavoSonarCard | Card/ecogramă; PRO are traseu separat |
| NavoSonarMapping | Probe/grilă/traseu; aproximativ 14.486 probe testate prin pipeline real |
| NavoSonarRecorder | Helper în memorie neinstanțiat; nu este recorder/export KLF brut dovedit |
| NavoFishDetector | Depth din CHART range/offset fizic, excluzând fundul; calitate detecție în teren restantă |
| NavoFishDetections | Colecție bounded; scriere replay blocată; coordonate/calitate live restante |
| NavoFishOverlay | Marcaje, ascunse în replay; calibrare/poziționare live restante |
| NavoBathymetryModel | Model legacy; nu înlocuiește procesorii nativi |
| NavoBathymetryOverlay | Overlay legacy; comutare HD logică, randare pe G20 restantă |
| NavoBathymetryHDModel | IDW/contururi; grilă/127 celule HD/148 segmente testate |
| NavoBathymetryHDOverlay | Heatmap/contururi; nu recalculează cât este oprit; G20 restant |
| NavoBathymetry3D | Mesh/LOD/cache/pick; gesturi reparate și formule verificate Qt; mesh/pick/touch cu date pe G20 restante |
| NavoEthernetSettings | IP/port/import/provider/video/units; binding sonar reparat, provider/LAN fizic restante |
| NavoEthernetIndicator | Stare LAN/sonar/video; TCP conectat nu confirmă video live |
| NavoCameraEthernet | Transport bytes; codec/protocol nu este presupus din bytes |
| NavoVideoPlayer | QtMultimedia RTSP/MJPEG/freshness/reconnect; cameră/codecs/credentials reale restante |
| NavoCameraPip | PiP; ascuns în PRO; stream G20 restant |
| NavoCameraFullScreen | Video/X; stream și interacțiuni fizice restante |
| NavoG20Settings | Preset/reset/dispatcher persistent; producător de evenimente fizice neidentificat |

## Backend și firmware

| Modul | Stare |
|---|---|
| CustomPlugin | Tipuri QML, default Boat, preferințe first-run; compilat Android |
| NavoKoggerDecoder | Fragmentare/checksum/raw/compensare și CHART v0 testate |
| NavoKoggerReplay | Fișier, ordine/GPS, pause/speed/EOF/stop și backpressure testate |
| NavoKoggerChartBridge | Canal/poziție/sample; TCP și replay reale testate |
| NavoKoggerDatasetAdapter | Dataset/Epoch/resolution/offset/retenție bounded testate |
| NavoKoggerService | Lifecycle/cozi/generații; bottom/surface și stale results testate |
| dataset/epoch/processors/bottom/surface | Subset adaptat al upstream integrat; nu întreaga suită de procesoare/UI Kogger |
| mosaic_db / mosaic_provider | Infrastructură prezentă; mosaic lateral dezactivat în service |
| NavoEthernetTransport | TCP/UDP/reconnect/freshness; TCP localhost verificat, LAN fizic restant |
| NavoKoggerTcpClient | Legacy înregistrat; SonarEthernet folosește transportul generic; audit duplicare restant |
| NavoLanDiscovery | Scan async bounded și endpoint protejat; ED2/cameră hardware restante |
| NavoMissionBridge | MAVLink reached/filter/QGC; misiune fizică restantă |
| NavoNanoTelemetry | Named values/senzori/lastUpdateMs; timeout conectat, hardware restant |
| NavoPersistence | Catalog atomic/rollback/citire independentă; legacy global rămas |
| NavoBathymetryMesh | IDW/cache/LOD, maxim 16 fișiere cache, hardness/echo incluse în cheie; acceptanță 3D restantă |
| NavoBathymetryGeometry / NavoTrack3DGeometry | Geometry Quick3D/color/traseu; compilate, scenă reală cu date restantă |
| Firmware.cpp/h / sketch / Config.h | Entrypoint Nano clasic reparat și compilat; calibrare/senzori/UART electric restanți |
| NavoLightCommand | Parser UART strict/buffer bounded și teste AVR/C++ verzi |
| LightControl / NavoH743Telemetry / protocol UART | Implementate; circuit RC light și encoder/end-to-end fizic restante |
| navo_nano_bridge.lua | Script real verificat cu mock UART/MAVLink; API și hardware ArduPilot restante |
| CMake / CustomOverrides / workflow-uri | Targeturi incluse; starea verificărilor relevante în tabelul CI |
| third_party/KoggerApp | Sursa și LICENSE GPL-3.0 păstrate; subset adaptat, nu UI Kogger complet |

## Ce împiedică acceptanța fizică finală

- G20/GR01: producătorul real de evenimente și long press, profilare touch/GPU/memorie și verificarea orientărilor.
- Barcă/H743/Nano: calibrare PWM/cursă, deconectare/reconectare, release/close și ACK/rejecție, senzori și UART electric.
- Kogger live și provider Android: KLF cu GPS, PRO, hartă/HD/3D, save/restart pe dispozitiv.
- CHART v1 și sincronizarea ceasului de achiziție: dovezi de dispozitiv necesare; arrival timestamp nu reprezintă sincronizare.
- Renderer direct al tile-urilor/export georeferențiat: nefinalizate; overlay-ul existent rămâne disponibil.
- DownView mosaic lateral/isobaths native: dezactivate până la geometrie validată.
- DigitalAnchor/EnergyGuard și helpers legacy: wiring/flux complet nelivrat; nu sunt declarate funcții active.
- AutoFix Guard: diagnostic-only; nu repară automat codul.
- CAD/PCB și instalația fizică nu au fost disponibile în această intervenție.

Actualizarea PDF-ului anterior este blocată de pierderea conexiunii la mediul local (environment_offline). Acest raport Markdown este versiunea actualizată și versionată în proiect; PDF-ul anterior nu reprezintă starea finală de mai sus.
