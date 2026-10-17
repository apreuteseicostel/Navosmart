# NAVO V3 — eliminare dependență activă Nano

Profilul V3 utilizează exclusiv mesaje MAVLink NV3* emise de serviciul H743. Backend-ul activ este NavoH743Telemetry; fișierele Nano au fost scoase din build-ul custom, păstrate numai în istoricul Git. Documentația și scripturile istorice Nano din repository nu sunt parte a configurației V3 active și necesită audit separat înainte de orice curățare fizică.

**Siguranță:** serviciul Lua H743 rămâne dezactivat implicit până la verificarea pinilor/parametrilor. Fără NV3VER proaspăt, connected=false, iar valorile nu sunt prezentate drept valide. Controlul luminilor rămâne blocat până la maparea verificată. Verificați Android CI și testele hardware înainte de merge.

## Verificare CI — 17 octombrie 2026

- Android workflow `39035361209` pentru commitul `6758c6f`: **success**. Acest rezultat confirmă compilarea, nu acceptanța pe hardware.
- PR #23 este încă `draft`, cu `mergeable_state=dirty` în API, deși comparația dintre SHA-ul bazei și SHA-ul head raportează `ahead` și `behind_by=0`. Nu interpretați automat această comparație drept absența conflictelor; starea merge trebuie revalidată explicit.
- Serviciul H743 și pinii reali rămân nevalidați; nu activați comenzile de cuve/lumini fără test fizic.
- Fișierele istorice Nano (`ardupilot/scripts/navo_nano_bridge.lua`, `firmware/NAVOMODEL_Arduino/`, `tests/firmware/nano-bridge.lua`, documentația Nano) rămân în repository pentru istoric. Nu fac parte din backend-ul V3 activ; curățarea și izolarea lor necesită audit suplimentar.
