# Înregistrare sonar și sesiuni offline

Sonar PRO → meniu → **Înregistrează sesiunea** → nume → **Pornește**.
Butonul este disponibil doar când sunt primite date sonar live. Indicatorul REC
și dimensiunea brută apar în meniu. **Oprește și salvează REC** finalizează sesiunea;
**Sesiuni offline** o redeschide fără conexiune la sonar. Replay-ul existent KLF
și salvarea rezultatelor procesate în „Bălțile mele” rămân disponibile.

## Date și limite

- Format propriu `.navosonar`, versiunea 1; nu este KLF și nu implementează
  protocolul Deeper. Stochează exact octeții primiți TCP/UDP, timpul relativ de
  recepție și coordonatele/atitudinea disponibile de la H743.
- Lipsa fixului GPS sau a legăturii H743 produce coordonate necunoscute. Nu se
  substituie GPS-ul live în replay. Poziția reprezintă recepția, fără garanția
  sincronizării cu timpul fizic al pingului sonar.
- Pachetele sunt împărțite în blocuri de maximum 64 KiB, cu aceeași poziție și
  același timestamp. SHA-256 verifică antetul și datele fiecărui bloc. Parserul
  sonar real reasamblează coloanele după replay, inclusiv între blocuri.
- Datele sunt scrise incremental, sincron, fără acumularea sesiunii în RAM.
  QSaveFile finalizează atomic în folderul privat al aplicației. Sesiunile
  goale și erorile de scriere nu sunt catalogate ca înregistrări reușite.
- Limita este 512 MiB / sesiune și șapte zile. Pornirea cere cel puțin 64 MiB
  liberi când spațiul poate fi determinat. Nu se șterg automat sesiuni vechi.
- Deconectarea explicită, schimbarea endpointului și pornirea replay-ului
  finalizează înregistrarea. O pierdere temporară de rețea păstrează sesiunea
  deschisă, cu pauza de recepție în timeline.
- **Oprește înregistrarea înainte de închiderea forțată a aplicației.** O oprire
  normală încearcă finalizarea; un crash/force-stop poate pierde sesiunea în curs.
  Fișierele temporare nu sunt prezentate ca sesiuni offline reușite.
- Catalogul enumeră înregistrările finalizate locale, în ordine descrescătoare.
  Replay-ul validează integral blocurile pe măsură ce le citește și afișează
  eroarea la trunchiere, checksum incorect sau metadate invalide.
- Replay-ul păstrează timpii relativi, acceptă 0.5–5×, pauză și backpressure-ul
  procesorului nativ. Citirea/livrarea este limitată per tick; viteza poate fi
  mai mică atunci când procesarea nu ține pasul. Rezultatele rămân vizibile la EOF.

Arhiva brută permite reprocesare offline prin decoderul și procesoarele native
existente. Nu este o arhivă completă a tile-urilor native sau a hărții de bază;
nu include încă export către alte aplicații, cloud sau recuperare după crash.
Debitul susținut și latența scrierii trebuie validate pe dispozitivul Android
folosit pe apă înainte de certificarea performanței.

## Verificare

- `tests/kogger-replay/recording.cpp`: roundtrip brut, împărțire, GPS valid/pierdut,
  finalizare atomică, restart, timpi, pauză/backpressure, fișiere goale, trunchiate,
  payload modificat și lungimi supradimensionate.
- `tests/kogger-replay/replay.cpp`: transportul TCP localhost real prin QML-ul de
  producție → recorder → arhivă → replay → decoder/Dataset nativ. GPS-ul live
  schimbat nu poate substitui poziția salvată. Fixture-ul KLF autentic rămâne testat.
- `tests/kogger-replay/replay-pacing.cpp`: protejează ritmul KLF existent.
- `tests/sonar-recording-ui.py`: Qt real, ferestrele la 320/480/900 px și pornire
  cu nume. Runner-ul CI C++ deschide aceleași ferestre la 320 px.

Testele pe desktop/CI nu înlocuiesc verificarea pe barcă și pe telefon.
