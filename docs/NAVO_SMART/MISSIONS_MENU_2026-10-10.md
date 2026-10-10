# Misiuni: trei fluxuri comune

Pagina 2 se numește **MISIUNI** și oferă **Mergi la punct**, **Traseu cu opriri**, **Scanează zona**.

Punctul unic și traseul folosesc același motor GUIDED, cu două schițe separate. Schimbarea editorului păstrează punctele și acțiunea finală ale celuilalt editor. Ambele schițe intră în snapshot-ul bălții; snapshot-urile vechi rămân compatibile și se restaurează ca schițe, niciodată ca misiuni active. „Aplică” înlocuiește explicit destinația punctului unic. La traseu, „+” adaugă o oprire. Acțiunile disponibile sunt navigare, stânga, dreapta, ambele cuve; o cuvă fizică poate fi folosită o dată per încărcare. START cu nădire cere confirmarea încărcării.

Configurarea punctului/traseului include viteza GUIDED efectivă (sau viteza de apropiere în modul silențios), cuvele, finalul HOME/ancoră GPS/HOLD, distanța, durata și verificarea energiei. Apropierea lentă, stabilizarea și ieșirea din zona de nădire rămân în estimare. Energia include rezerva pentru HOME chiar când finalul este HOLD/ancoră.

Scanarea păstrează desenarea, pregătirea, upload-ul verificat, START separat și reluarea culoarelor incomplete. Nu eliberează cuve. Viteza editabilă din panoul său este explicit **viteza de estimare**, nu o comandă către H743. AUTO folosește viteza configurată în autopilot. Durata afișată nu include virajele și nu garantează timpul fizic. Finalul scanării este HOLD sau RTL.

Bara de misiune este persistentă în Dashboard în timpul operațiilor, inclusiv pe Sonar PRO. Afișează progresul, etapa, conexiunea, PAUZĂ și HOME. Progresul GUIDED combină opririle comandate cu distanța rămasă pe segment; segmentul este limitat la 95% până când ciclul se încheie. 100% înseamnă acțiunile opririlor comandate; nu confirmă poziția cuvelor sau sosirea la HOME.

PAUZĂ folosește HOLD. La scanare, controlerul păstrează culoarele confirmate și permite pregătirea reluării. La punct/nădire/traseu, HOLD anulează ciclul și callback-urile următoare; după verificarea cuvelor este necesar un nou START cu confirmarea încărcării. Nu se presupune o reluare sigură a unei eliberări întrerupte. HOME deschide confirmarea RTL existentă. Comenzile sunt dezactivate la pierderea conexiunii; controlerele de siguranță existente rămân responsabile de reacția la pierderea GPS/legăturii și schimbarea modului pilotului. Replay-ul nu permite alegerea/editarea/START de misiuni live.

Panoul se așază sub hartă pe ecrane înguste și lângă hartă pe ecrane largi. Configurarea și uneltele de scanare pot fi derulate; bara PAUZĂ/HOME rămâne vizibilă.

## Verificare

- `node tests/audit-regressions.mjs`: 51 scenarii existente.
- `node tests/route-plan.mjs`: 15 scenarii, inclusiv schițe separate, restaurare, blocare în replay/misiune activă și refuzul modurilor invalide.
- `node tests/g20-input.mjs`: 7 scenarii RC existente.
- `python tests/missions-ui.py`: layout-ul paginii și bara extrase din QML-ul de producție, cu hartă și hardware substituite; toate cele trei moduri la 236/320/480/900 px, blocare la schimbarea selecției active, semnale PAUZĂ/HOME și dezactivare la pierderea legăturii. Inclus în CI firmware/persistence cu PySide6 6.8.3.
- `python tests/route-ui.py`, `python tests/sonar-recording-ui.py`: componentele existente Qt continuă să se încarce.

Compilarea Android și validarea pe dispozitiv/barcă sunt verificări separate. Această schimbare nu adaugă reglarea cârmei pentru mers drept și nu clasifică fizic mâl/pietriș/vegetație. Asistența de direcție trebuie implementată și calibrată în H743 pentru motor unic + cârmă. Analiza ecourilor Kogger trebuie comparată cu măsurători reale; această interfață nu creează un modul DownScan.
