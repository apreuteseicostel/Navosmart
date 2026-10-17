# NAVO V3 — eliminare dependență activă Nano

Profilul V3 utilizează exclusiv mesaje MAVLink NV3* emise de serviciul H743. Backend-ul activ este NavoH743Telemetry; fișierele Nano au fost scoase din build-ul custom, păstrate numai în istoricul Git. Documentația și scripturile istorice Nano din repository nu sunt parte a configurației V3 active și necesită audit separat înainte de orice curățare fizică.

**Siguranță:** serviciul Lua H743 rămâne dezactivat implicit până la verificarea pinilor/parametrilor. Fără NV3VER proaspăt, connected=false, iar valorile nu sunt prezentate drept valide. Controlul luminilor rămâne blocat până la maparea verificată. Verificați Android CI și testele hardware înainte de merge.
