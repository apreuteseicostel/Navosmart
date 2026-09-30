# NAVO SMART — Safety & Integration

H743 este autoritatea critică. Nano, Android, LAN, sonar și camera nu trebuie să fie puncte unice de defect pentru propulsie, cârmă, cuve sau revenirea în siguranță.

- Nano căzut: H743 păstrează motor/cârmă/cuve și modurile de siguranță; se pierd auxiliare/telemetrie Nano.
- aplicație/LAN căzute: H743 + RC păstrează controlul și failsafe.
- GPS invalid: comportamentul final se stabilește în ArduPilot și se testează hardware; nu se bazează revenirea pe poziție invalidă.
- RC/GCS pierdut: H743 este autoritatea failsafe.

Reguli: o singură autoritate directă per servo; cuvele comandate de H743, Nano doar monitorizează; nu se paralelizează surse 5 V; GND comun unde interfețele îl cer; hardware-ul se validează electric înainte de JLCPCB; parametrii și pinout-urile se reverifică înainte de conectare fizică.
