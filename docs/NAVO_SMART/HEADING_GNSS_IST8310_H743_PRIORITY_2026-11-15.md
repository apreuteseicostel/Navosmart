# NAVO SMART — prioritizare orientare UM982 → IST8310 → H743

**Implementare:** PR pentru C++ / dashboard NAVO, **nu modifică automat parametrii de zbor** ai H743. Matek H743-Wing V3 nu are busolă integrată; în testele QGroundControl anterioare a fost raportat un IST8310 extern pe I2C1, dar conectarea permanentă, calibrarea și utilizarea efectivă nu sunt încă demonstrate.

## Ordinea exactă în aplicație

1. **UM982** — `GPS_RAW_INT.yaw` din GPS1, altfel `GPS2_RAW.yaw` din GPS2, doar când `fix_type>=3`, cel puțin 4 sateliți, yaw valid 1..36000 centidegrees și pachet sub 3 secunde; nu se folosește COG. GPS1 este *configurat* ca UM982, dar doar ID-ul MAVLink nu dovedește producătorul fizic.
2. **Busolă externă (IST8310 de confirmat)** — `vehicle.heading` al EKF3 numai când **toate** condițiile sunt confirmate: `EK3_SRC1_YAW=3` primit din PARAM_VALUE, `COMPASS_USE=1`, `COMPASS_DEV_ID>0`, `SYS_STATUS` cu magnetometru prezent+activ+healthy în ultimele 5s și mesaj `EKF3 IMU… yaw fallback active` de la componenta autopilot. Mesajul `yaw external` sau revenirea GNSS yaw revocă acea stare. `vehicle.heading` este unghiul de yaw fuzionat al EKF, nu magnetometrul brut; verificarea exactă a modelului IST8310 rămâne fizică.
3. **H743 / EKF temporar** — dacă cele de mai sus nu sunt disponibile, `vehicle.heading` poate fi afișat **cel mult 12 secunde după ultimul yaw absolut valid** (GNSS sau busolă confirmată), etichetat clar `H743 / EKF (temporar)`. Nu este o busolă și nu poate menține nordul absolut pe termen lung doar cu giroscopul. Fără referință precedentă se afișează `HEADING --`; nu se inventează nord sau compass.

Pe toți cei patru NavoMap și pe cele două busole vizuale funcționează aceeași valoare `gnssHeading.selectedHeadingDeg`. GPS position vs GPS yaw sunt două verificări diferite. În diagnosticul GNSS sunt vizibile sursa selectată, starea magnetometrului, setarea EKF3 și motivul oricărei degradări. La pierderea MAVLink sau schimbarea vehiculului stările sunt invalidate.

## Parametrii H743 de verificat — nu scriem automat

- `AHRS_EKF_TYPE=3`, `EK3_ENABLE=1`
- `GPS1_TYPE=25` pentru UM982 Moving Baseline; portul real `SERIALx_PROTOCOL=5` (GPS), baud conform instalării, offsetul antenelor/rigid baseline 33 cm corect măsurat și orientat.
- **`EK3_SRC1_YAW=3` (GPS with Compass Fallback)** numai după configurarea și calibrarea IST8310. ArduPilot poate învăța offseturile busolei cât GPS yaw este bun. `EK3_SRC1_YAW=2` este GPS-only și nu poate activa această rezervă.
- `COMPASS_DEV_ID` nenul, `COMPASS_USE=1`, `COMPASS_EXTERN` sau orientarea/external flag după firmware, `COMPASS_ORIENT`, calibrare, interfețele I2C1 SDA/SCL; pe H743 nu există compas intern.
- GNSS fix fără yaw (0/65535) nu este suficient. Nu activa AUTO/RTL până nu confirmi yaw EKF corect, HOME și poziția GPS. Un magnetometru nu ține loc de GPS pozițional.

**Teste fizice:** într-un loc deschis, cu elicea/motorul decuplate pentru primele teste, pornește GNSS, rotește barca cu antenele fixate (la minim 30cm). Verifică că GPS1 yaw variază; simulează pierderea soluției dual GNSS și observă dacă firmware-ul raportează `yaw fallback active`, iar NAVO arată `Busolă externă / EKF3`. Apoi scoate busola / simulează eroare magnetică: NAVO afișează temporar H743 estimativ, apoi `HEADING --`. Realizează interferență magnetică/curent ESC tests numai în condiții controlate cu posibilitatea de stop manual.

**Nu configura busola prin codul Android:** `EK3_SRC1_YAW=3`, `COMPASS_USE=1` și calibrarea modifică efectiv navigația autonomă. Modificările aplicației sunt pasive; cere exportul `.param` și verifică hardware înainte de a schimba acești parametri pe barcă.

Surse oficiale:
- https://ardupilot.org/rover/docs/common-gps-for-yaw.html
- https://ardupilot.org/rover/docs/common-ekf-sources.html
- https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_NavEKF3/AP_NavEKF3_MagFusion.cpp
- https://mavlink.io/en/messages/common.html
