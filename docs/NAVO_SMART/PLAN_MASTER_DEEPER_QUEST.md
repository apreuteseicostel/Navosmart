# NAVO SMART — PLAN MASTER DE ÎMBUNĂTĂȚIRI
Versiunea 1.0, 17 octombrie 2026. Transcriere fidelă în structură și criterii a documentului Word furnizat; document de planificare, nu validare hardware.

## Scop și principii
Benchmark Deeper QUEST; păstrăm H743 + UM982 + Kogger + G20/GR01. ArduPilot este autoritatea de siguranță. Nu expunem comenzi nevalidate, nu copiem praguri comerciale de baterie și nu schimbăm PCB-ul fără justificare electrică.

## Benchmark
| Domeniu | QUEST (afirmații comerciale) | NAVO SMART |
|---|---|---|
| Navigație | Autopilot, revenire, Co-Pilot | H743/ArduPilot + UM982; test apă necesar |
| Sonar | CHIRP, trei fascicule, DownScan opțional | Kogger Sonar Pro în integrare |
| Cartografiere | 3D și Area Scan | Area Scan, cache/3D în dezvoltare |
| Telecomandă | Controler dedicat | G20 + GR01; mapare de verificat |
| Siguranță | RTL la link/baterie | Failsafe ArduPilot, nevalidat end-to-end |
| Pescuit | Hărți și puncte | Replay, adnotări, jurnal, offline planificate |

## Backlog master și acceptanță
1. **P0 Failsafe/RTL adaptiv:** pierdere link, GNSS invalid, baterie joasă, eșec motor, energie conservatoare pentru retur, prioritate manuală. Acceptanță: simulator + banc + apă, jurnal și recuperare sigură. Stare: nevalidat.
2. **P0 Co-Pilot/stabilizare:** IMU, GNSS heading, motoare diferențiale, anti-windup, filtrare, semnal degradat. Acceptanță: abatere măsurată cu/fără vânt și curent, fără oscilații. Stare: audit firmware necesar.
3. **P1 Area Scan:** zig-zag, distanță linii, viteză, ETA, geofence, pauză/reluare. Acceptanță: misiuni corecte și reluare verificată. Stare: în lucru.
4. **P1 Kogger Sonar Pro/replay:** CHART real, timestamp/GNSS, adâncimi în metri, scală, canale, mozaic, KLF. Acceptanță: decodare reproductibilă, test G20. Stare: integrare în dezvoltare.
5. **P1 Batimetrie 3D/cache:** izobate, grilă, tile cache, 2D/3D, export, GPS, puncte eronate. Acceptanță: live/replay identic, cache persistent, performanță G20. Stare: nevalidat integral.
6. **P2 Adnotări replay/jurnal:** ecograme, notițe, capturi, monturi, nădire, pești, temperatură, adâncime, timp și hartă. Acceptanță: asociere timp/poziție, persistă la restart, export verificat. Stare: de confirmat.
7. **P2 Offline complet:** descărcare zonă, cache, poziții, misiuni, jurnal și sincronizare opțională. Acceptanță: misiune și replay fără internet. Stare: planificat.
8. **P2 Monitorizare temperatură/umiditate interioară:** senzor în corpul bărcii, praguri și alertă; ventilație numai după analiză etanșare/condens/consum. Acceptanță: alerte repetabile și IP carcasă păstrat. Stare: cerință nouă.
9. **P2 Stealth:** profil lumini/viteză/sunete, fără dezactivarea avertizărilor critice sau luminilor obligatorii. Acceptanță: RTL și geofence neafectate. Stare: propus.
10. **P2 Substrat/vegetație:** mostre sonar etichetate, indicatori ecou și clasificare experimentală cu încredere; fals-pozitive raportate. Acceptanță: observații reale. Stare: cercetare.

## Ordine și dependențe
A P0: ArduPilot/MAVLink, siguranță, RTL, manual, stabilizare; banc înainte de apă.
B P1: Kogger CHART → replay sincronizat → mozaic → izobate → cache/3D.
C P1: Area Scan, Digital Anchor, nădire și misiuni repetabile după siguranță.
D P2: adnotări → jurnal → offline → alerte → umiditate → Stealth → substrat.

## Protocol
Clasificare pe funcție: IMPLEMENTAT / PARȚIAL / LIPSĂ / NECESITĂ TEST HARDWARE, cu fișiere și commituri. Android APK și replay verzi la același SHA; banc (link, baterie, cuve, manual/auto, restart, GNSS); apă progresiv cu recuperare și loguri; acceptanță documentată înainte de merge.

## Audit de progres — 17 octombrie 2026 (PR #23)

**Regulă:** existența codului sau un APK verde nu echivalează cu acceptanța funcției. Etichetele de mai jos sunt conservatoare și nu presupun teste pe barcă.

| # | Clasificare | Dovezi de cod / lacune decisive |
|---|---|---|
| 1 | PARȚIAL / NECESITĂ TEST HARDWARE | `custom/qml/NavoDashboard.qml`: `failsafeController`, `energyGuard`, `rtlMission`; fără validare link/GNSS/baterie/motor la banc și pe apă. |
| 2 | NECESITĂ AUDIT FIRMWARE | Stabilizarea ArduPilot/H743 nu are măsurători comparative anti-windup, curent/vânt sau feedback motor. |
| 3 | PARȚIAL | `custom/qml/NavoDashboard.qml`: `scanCoordinator`, pauză/reluare; acceptanța misiunilor și geofence încă neconfirmată. |
| 4 | PARȚIAL | Componente Kogger, replay și teste CHART; fără acceptanță completă canal real, sincronizare GNSS și mozaic pe G20. |
| 5 | PARȚIAL | Mesh/batimetrie în backend; cache persistent, identitate live/replay și performanța G20 încă neconfirmate. |
| 6 | DE VERIFICAT | Adnotările și jurnalul necesită test de persistență/restart/export, nu se declară finalizate. |
| 7 | LIPSĂ ACCEPTANȚĂ | Hărți offline complete, misiune și replay fără internet nevalidate. |
| 8 | LIPSĂ IMPLEMENTARE | DHT11 selectat; pin H743 nealocat și firmware fără citire/umiditate confirmată. |
| 9 | PROPUS | Stealth necesită profil explicit fără reducerea siguranței, RTL sau geofence. |
| 10 | CERCETARE | Clasificarea substratului/vegetației necesită mostre reale etichetate și raportarea fals-pozitivelor. |

**Ordinea execuției:** (1) P0 RTL/failsafe + Co-Pilot; (2) P1 CHART Kogger + Area Scan + 3D/cache; (3) P2 adnotări/jurnal → offline → DHT11 → Stealth → substrat. Pentru fiecare: test automat, APK la același SHA, banc, apă, apoi acceptanță. Nu se face merge doar pentru că CI este verde.

## Riscuri
CHART Kogger, UM982 calibrare, feedback turație, energie RTL, consum sonar/cameră, umiditate, resurse G20.

## Surse
https://deepersonar.com/products/quest (prezentare comercială); https://github.com/apreuteseicostel/Navosmart ; discuțiile NAVO SMART, octombrie 2026.

## Decizie suplimentară — DHT11
Utilizatorul a selectat DHT11 pentru aerul din interiorul bărcii. Pinul H743 este NEALOCAT până la validarea pinout-ului, firmware-ului și a parametrilor. Vezi ../hardware/DHT11_H743_INTEGRARE.md. Nu se confundă cu NTC-ul bateriei ori senzorul de apă. Nu se declară implementat.