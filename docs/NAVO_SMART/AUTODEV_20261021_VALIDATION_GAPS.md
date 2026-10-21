# NAVO SMART — verificări suplimentare (21 octombrie 2026)

Acest document consemnează doar dovezi software. Nu există validare hardware.

## Android

- [CI #39505769006](https://github.com/apreuteseicostel/Navosmart/actions/runs/39505769006): au trecut compilarea și semnarea APK-urilor arm64 și x86_64; pasul emulatorului a eșuat.
- `.github/workflows/android.yml` păstrează arborele `build-x86` după semnare, înainte de pornirea emulatorului. Remedierea propusă este păstrarea APK-ului semnat, ștergerea output-urilor intermediare x86_64, restaurarea APK-ului și verificarea spațiului liber. Nu există commit de remediere.
- `tests/android/ui-smoke.py` de pe branch-ul Android poate apăsa un buton de navigare tăiat; PR #25 conține o corecție separată, dar nu reprezintă validare completă pe emulator.

## Siguranță H743

- PR #21 `NavoSafetyManager.qml` SHA `6e4b34bc` include `temperatureValid`, `waterValid`, resetare la schimbarea vehiculului și confirmarea apei numai când senzorul este valid.
- PR #23 `NavoSafetyManager.qml` SHA `226936ed` nu include aceste condiții. Testul `tests/hardware-safety-ui.py` din consolidare folosește `waterValid`, astfel implementarea și testul sunt incompatibile.
- Integrarea MANUAL/ACRO există pe branch-ul izolat `fix/p0-manual-v3-integration-20261020`, dar fără test Android sau hardware acceptat.
- Nu se dezactivează protecțiile ArduPilot și nu se face merge înainte de testare.

## Agent

Workflow-ul `navo-autodev-agent.yml` conține gardă de activare prin `NAVO_AUTODEV_ENABLED`. Agentul nu a fost executat; nu se activează până la aprobarea utilizatorului.

Operațiunile de scriere pentru workflow Android, testul UI și controllerul de siguranță au fost blocate de verificările de securitate ale instrumentelor GitHub. Documentarea nu constituie implementare sau validare.
