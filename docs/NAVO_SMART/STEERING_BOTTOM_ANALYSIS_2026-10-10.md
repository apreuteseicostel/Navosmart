# Asistență cârmă H743 și analiză relativă Kogger

## Setări → Asistență cârmă

NAVO folosește modul **STEERING raportat de ArduPilot Rover**. Modul încearcă să mențină direcția când manșa de direcție revine la neutru; viteza este comandată din G20. H743 reglează cârma și propulsia. NAVO nu trimite PWM, RC override, control diferențial sau un PID concurent.

Referințe oficiale:
- https://ardupilot.org/rover/docs/steering-mode.html
- https://ardupilot.org/rover/docs/rover-motor-and-servo-connections.html

Configurația motor unic + cârmă folosește funcțiile Ground Steering (26) și Throttle (70), pe ieșirile fizice alese și verificate. Documentația ArduPilot exemplifică SERVO1/SERVO3; NAVO nu presupune și nu rescrie automat aceste ieșiri. Configurația cu Throttle Left/Right (73/74) este diferită și nu este configurată de această funcție.

Activarea este explicită, după confirmarea din panou. Este blocată dacă H743 nu raportează STEERING în `flightModes`, vehiculul nu este Rover, lipsesc legătura/GPS/direcția, PRE-LAUNCH nu este pregătit, există misiune/upload/ancoră sau rulează replay. Nu armează vehiculul. Starea este REQUESTED până când telemetria confirmă STEERING, cu timeout de 5 secunde.

OPREȘTE trimite HOLD prin API-ul Vehicle și așteaptă confirmarea. Schimbarea pilotului la MANUAL/AUTO/alt mod eliberează monitorizarea fără a trimite HOLD peste modul pilotului. Pierderea telemetriei/GPS suspendă monitorizarea; revenirea lor nu reactivează automat STEERING. Suspendarea monitorizării nu demonstrează oprirea fizică a bărcii. Failsafe-urile existente și configurația FS_* din H743 rămân necesare și trebuie testate. Misiunile GUIDED/Area Scan și ancora nu se pornesc peste o asistență activă/pending din NAVO.

Asistența menține un cap în condițiile modului STEERING, nu promite o linie GPS exactă sau evitarea obstacolelor. Vântul/curentul pot deplasa barca lateral. Direcția cârmei, neutrele, sensul ESC, limitele de viteză și reglajele H743 trebuie validate fizic. PID-ul nu este calibrat de acest panou.

## Sonar PRO → Analiză fund și ecouri

Analiza folosește ultima coloană CHART afișată, ecoul **brut normalizat 0–1**, scara fizică a coloanei și fundul procesat care corespunde aceleiași secvențe. Coloanele native care încă așteaptă fundul nu primesc un fund preluat din altă secvență. Coloana brută este păstrată împreună cu cea afișată; gain-ul, paleta, filtrul și compensarea vizuală nu intră în metrici. Analiza se calculează numai când dialogul este vizibil.

Măsurători descriptive:
- adâncimea fundului și pasul vertical CHART;
- maximul și media amplitudinii în jurul fundului, într-o fereastră de cel puțin ±0,15 m și ±3 bin-uri;
- lățimea verticală a returului la jumătatea maximului; `≥` indică tăierea la marginea ferestrei;
- grupuri de cel puțin 3 bin-uri peste pragul euristic max(0,2, mediană apă + 0,15), cu distanța verticală față de fund;
- min/max și variația verticală pentru cel mult 40 de coloane recente cu fund în scara lor validă.

Lipsa scării/fundului, fereastra trunchiată sau amplitudini invalide în zonele analizate produc „indisponibil”, nu ecou zero sau un material. Ecourile deasupra fundului pot proveni din pești, vegetație, obiecte, zgomot și alte surse. Numărul grupurilor nu este număr de pești sau identificare de structuri. Variația temporală a adâncimii nu este pantă fără distanță GPS validată.

**Materialul rămâne NECLASIFICAT.** Procentele sunt amplitudini brute relative, nu duritate, probabilitate sau încredere în „mâl/pietriș”. Clasificarea fizică necesită probe de referință, condiții de achiziție comparabile, validare pe date independente și evaluarea erorilor. Nu este adăugat un traductor/mod DownScan.

## Verificări și acceptanță rămasă

- 10 scenarii în `tests/steering-bottom.mjs`: mod disponibil, prelaunch, replay/busy/GPS/link, confirmare/timeout, MANUAL, HOLD, lipsa reluării automate, metrici cunoscute, date/scară invalide, lățime trunchiată și profil mărginit.
- `tests/steering-ui.py`: controler și panou Qt reale la 236/320/480/900 px, confirmare, telemetrie simulată, HOLD și blocare la deconectare.
- `tests/sonar-recording-ui.py`: dialog de analiză din Sonar PRO real la 320/480/900 px; metricile brute nu se schimbă cu gain/floor sau cu coloane afișate compensate.
- Cele 51 de scenarii existente, 15 misiuni și 7 G20 rămân verzi local. Testele noi sunt incluse în CI firmware/persistence și suita JS în Android.

Aceste teste nu sunt acceptanță fizică. Rămân: H743/UM982/G20 pe banc și pe apă, răspuns cârmă/ESC, pilot takeover, HOLD/FS_*, pierdere/revenire GPS/link, apoi comparații Kogger cu probe reale de fund. PR-ul rămâne draft până la verificările instalate și fizice convenite.
