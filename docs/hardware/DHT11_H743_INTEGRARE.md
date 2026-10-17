# NAVO SMART V3 — DHT11 interior / H743
**Stare: propunere, nu cablați și nu activați încă.** Completează cerința 08 din Planul Master.

DHT11 va măsura temperatura aerului (°C) și umiditatea relativă (%) în corpul bărcii. Senzor separat de NTC-ul bateriei și detectorul de apă.

## Conexiuni propuse, NU pinout final
| Pin DHT11 | Destinație | Condiție |
|---|---|---|
| VCC | 3.3 V stabil | numai dacă modulul concret acceptă 3.3 V |
| DATA | GPIO digital 3.3 V disponibil pe Matek H743-WING V3 — **TBD** | trebuie verificat în pinout și configurația ArduPilot; NU conecta la 5 V |
| GND | GND comun | cablu scurt, protejat |
| DATA pull-up | 4.7–10 kΩ spre 3.3 V dacă modulul nu o include | verificați placa modulului |

DHT11 folosește un protocol digital bidirecțional cu impulsuri de ordinul microsecundelor. **Nu este UART, I²C, ADC sau OneWire DS18B20.** Nu se poate implementa fiabil doar prin citire GPIO periodică în Lua fără driver/timing demonstrat. Înainte de cablare trebuie confirmată o cale de citire compatibilă ArduPilot H743; dacă nu există, este necesar un coprocesor ori alegerea altui senzor cu bus suportat (decizie separată).

## Integrare necesară
1. Audit pinout Matek H743-WING V3 și export .param; GPIO rezervate pentru GR01, UM982, Kogger, servo, lumini, RGB, apă și NTC. **Nu alocăm un pin fără această verificare.**
2. Driver cu checksum, timeout, retry, citire cel mult o dată la 2 secunde, indicator invalid/stale.
3. Telemetrie MAVLink distinctă propusă: NV3HUM pentru % RH și NV3ITMP pentru °C; acestea NU sunt implementate încă.
4. Dashboard: Temperatură interioară și Umiditate interioară, unități, indicator prospețime, praguri configurabile, alerte și jurnal.
5. Lipsa datelor nu devine 0%; umiditatea nu dovedește infiltrare. Nu bloca armarea, navigația sau RTL pe baza DHT11.
6. Test pe banc: tensiuni, checksum, eșec citire, restart, umiditate/condens, latență, sarcină CPU și izolarea failsafe. Test carcasă: nu compromite etanșarea.

## Limitări
DHT11 este ieftin, lent și cu precizie modestă; nu este detector certificat de infiltrații, nu trebuie expus apei lichide. Alternativa DHT22/SHT3x poate fi evaluată ulterior dacă este nevoie de performanțe mai bune, fără schimbarea cerinței curente.

## Matrice acceptanță
| Componentă | Stare |
|---|---|
| Cerință documentată | DA |
| Pin GPIO H743 | TBD, neconfirmat |
| Driver H743 | LIPSĂ |
| MAVLink | PROPUS |
| UI/alarme | DE IMPLEMENTAT |
| Test hardware | NEEXECUTAT |
