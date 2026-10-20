# NAVO SMART PR #20–23 — audit de reconciliere (20 octombrie 2026)

Audit de cod, nu acceptanță hardware. Bază: `main`; țintă: `integration/pr20-v3-consolidation-20261017`. Niciun merge în main.

| Domeniu | Clasificare | Dovadă / pas |
|---|---|---|
| PR #20: misiuni, replay, jurnal, offline, G20 | INTEGRAT ÎN COD / NECESITĂ TEST | Componentele din PR #20 sunt în consolidare, dar fără acceptanță pe G20. |
| PR #21: Lua H743 V3 și teste firmware | INTEGRAT IDENTIC | `ardupilot/scripts/navo_v3_service.lua` SHA `d463e18d`; `tests/firmware/v3-service.lua` SHA `27d7aa9c`. |
| PR #21: valabilitate senzori | LIPSĂ — P0 | `NavoSafetyManager.qml` SHA PR21 `6e4b34bc` vs consolidare `226936ed`. Lipsesc `temperatureValid`, `waterValid`, resetarea la schimbarea vehiculului și protecția confirmării apei la invalidare. `tests/hardware-safety-ui.py` folosește `waterValid`. |
| PR #21: ciclu cuve | ÎNLOCUIT PARȚIAL / RECONCILIERE P0 | `NavoHopperBridge.qml` PR21 `c69d6fde`, consolidare `2eae318c`. Consolidarea verifică `hardwareTelemetry.connected`, dar nu mai verifică `commandPending` la eliberare. Nu reintroduce codul PR21 fără reconciliere. |
| PR #21: finalizare nădire | LIPSĂ / RECONCILIERE P0 | `NavoBaitingController.qml` PR21 `1fbcb722` vs consolidare `1ab87f42`; lipsește așteptarea `releaseComplete` înainte de închiderea ciclului. |
| PR #21: alerte senzori | LIPSĂ / RECONCILIERE P1 | `NavoAlerts.qml` PR21 `f000e887` vs consolidare `2df850ba`; lipsesc condițiile independente `waterValid` și `temperatureValid`. |
| PR #21: persistență | NECESITĂ AUDIT | `NavoPersistence.cc` SHA PR21 `5d61d5af` vs consolidare `bc06e0ba`; verifică migrarea profilului V2/V3 și jurnalul înainte de merge. |
| PR #21: Nano telemetry | ÎNLOCUIT INTENȚIONAT | Consolidarea folosește `NavoH743Telemetry.*`; nu se restaurează Nano în V3. |
| PR #22: busolă | INTEGRAT IDENTIC | `NavoHeadingCompass.qml` SHA `b48b1447` în #22 și consolidare. |
| PR #22: Dashboard | ÎNLOCUIT / EXTINS | Consolidarea adaugă H743 V3 și alte fluxuri; cere verificare de interacțiuni. |
| PR #23: RTL la pierdere link | CORECTAT PE BRANCH IZOLAT, NEVALIDAT CI | `fix/p0-manual-v3-integration-20261020`: commituri `8ff093d6`, `9d67ce2b` protejează MANUAL/ACRO fără modificarea failsafe-urilor ArduPilot. |
| PR #24: agent Codex orar | NU SE ACTIVEAZĂ | `NAVO_AUTODEV_ENABLED` rămâne dezactivat până la validare și aprobare. |

## CI Android și cauza reală
Jobul Android #39340555534, job ID 118458199434, conține la compilarea x86_64 `fatal error: error in backend: IO failure on output stream: No space left on device` în mai multe fișiere C++. Arm64 a trecut, emulatorul nu a pornit. Jobul #39401374166 a eșuat tot la x86_64, dar logul său a returnat 404 BlobNotFound, deci cauza exactă a acelui job nu este confirmată. Corecție propusă: salvarea APK arm64, ștergerea arborelui `build/` arm64 și verificarea spațiului înainte de x86_64. Scrierea workflow-ului a fost respinsă de instrumentul GitHub; nu există commit pentru corecție.

## Priorități
1. P0: senzori H743 (validitate independentă, leak latch), blocarea comenzilor duplicate cuve, finalizarea nădirii doar la confirmare, teste Qt/Node.
2. Android: remediere ENOSPC, CI x86_64, smoke test emulator, APK artifact la același SHA.
3. P1: alerte, persistență V2/V3, replay, offline; apoi P2.
4. Agent Codex: doar inspecție statică sau test manual controlat, fără cron/variabilă de activare.

Fără dovadă de test fizic; fără aprobare de merge.
