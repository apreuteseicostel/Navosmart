# NAVO SMART — alarmă critică apă în cocă și RTL de urgență

**Data:** 13 noiembrie 2026  
**Stare:** DRAFT SOFTWARE, netestat / fără APK, **fără PR și fără build la cererea utilizatorului**.  
**Branch:** `feature/water-emergency-rtl-ui-draft-20261113`.  
**Integrare viitoare:** cu celelalte modificări solicitate, înainte de un singur build comun.

## Cerința

La apă detectată și **confirmată** în cocă:
1. Dashboard cu avertizare **mare, roșie, persistentă:** „⚠ PERICOL — APĂ ÎN COCĂ!”
2. **Alarmă sonoră critică** repetată la 6 s, independent de preferința pentru alertele sonore obișnuite și de modul Stealth. Alertele vizuale nu dispar la oprirea sunetului.
3. **Solicitare automată RTL / Home**, fără dialog de confirmare, numai cu GPS fix și HOME valide, telemetrie actuală și conexiune activă la H743. Nu declara un RTL activ înainte ca ArduPilot să raporteze modul RTL.

## Fluxul implementat în draft

Sursa este actualul `NavoSafetyManager.qml`, care deja are o confirmare de apă de **4 secunde** (`waterConfirmMs=4000`). Nu scurtăm confirmarea fără teste fizice și calibrare: o citire umedă izolată nu trebuie să declanșeze o manevră autonomă.

`waterConfirmed` stabilește un `waterAlarmLatched` care rămâne pe ecran și dacă legătura / senzorul expiră. Se poate opri sunetul, dar nu se poate ascunde alerta până când lectura live este uscată și utilizatorul apasă „Confirmă după uscare”. În intervalul cât apa este confirmată, verificarea condițiilor GPS/HOME se repetă la 1 s **fără** retrimitere repetată de comenzi. Când ele sunt îndeplinite, se emite **o singură** solicitare de RTL.

În dashboard, solicitarea RTL folosește calea existentă `rtlMission()`, care anulează operațiile NAVO active înainte de apelul către `Vehicle.guidedModeRTL(false)`. Pentru apa confirmată, această cale de urgență poate solicita RTL chiar dacă interfața era în MANUAL/ACRO; utilizatorul păstrează controlul fizic al comutatorului CH5, astfel că trebuie testată posibilitatea ca MANUAL să prevaleze din nou. Nu se dezactivează failsafe-urile H743.

Dacă GPS/HOME sau conexiunea sunt invalide: **NU** se inventează o rută și **NU** se afișează „RTL activ”; dashboard arată „RTL IMPOSIBIL / NEEXECUTAT — preia controlul”. Conexiunea și validitatea GPS sunt necesare și la orice încercare ulterioară. Ecranul roșu și sunetul nu depind de succesul comenzii RTL.

Audio folosește tonul NAVO deja instalat `alert.wav`, repetat la fiecare 6 secunde; în timpul alarmei se cere volum intern de cel puțin 85%. Dacă G20 are volum media zero, difuzorul e defect, aplicația e suspendată sau `SoundEffect` nu se încarcă, sunetul **nu este garantat**. Pentru protecție reală independentă de Android, în viitor este necesară alarmare/RTL **la bord**, într-un serviciu H743 testat fizic. Nu se face această activare Lua în acest branch.

## Dependențe și limitări

- Sensorul V3 apă în cocă trebuie să furnizeze semnal **live, valid**, cu praguri uscat/umed calibrate. Serviciul de diagnoză din [PR #72](https://github.com/apreuteseicostel/Navosmart/pull/72) este separat și nu este încă inclus automat în acest branch.
- `waterRtlRequested` înseamnă **solicitare transmisă**, nu acceptare MAVLink sau întoarcere fizică; verificarea modului RTL și teste cu G20/H743 sunt obligatorii.
- Nu se modifică pinii J11/J12, nivelurile ADC, Lua, parametrii de releu / CH5 ori circuitele de propulsie.
- Dacă aplicația se închide sau conexiunea se pierde, **nu poate garanta RTL**. Protecția nativă H743 rămâne necesară separat.
- După o alertă resetată doar când senzorul e uscat, un nou eveniment de apă poate declanșa din nou alarmă/RTL.
- Nu există operare a senzorului ori a bărcii din acest commit: modificările sunt cod de aplicație, păstrate fără APK până la finalizarea tuturor cerințelor.

## Teste de acceptanță înainte de merge / build final

1. Date absente, sensor invalid și replay: fără alarmă falsă și fără RTL.
2. Stare umedă scurtă sub 4 s: fără activare automată a RTL.
3. Umed continuu minim 4 s: banner roșu persistent și ton repetat chiar dacă alertele obișnuite sunt OFF.
4. GPS/HOME valide: o singură solicitare RTL, apoi verificarea modului raportat, traseului și răspunsului autopilotului.
5. GPS/HOME invalide: alarmă prezentă, fără rută inventată; după recuperare se poate solicita RTL **o singură dată**, numai pe legătura actuală.
6. MANUAL/ACRO, CH5, HOLD și RTL: teste pe banc cu motorul izolat, fără schimbări necontrolate de mod sau retrimiteri ciclice.
7. Pierdere MAVLink, fault senzor, reconectare, schimbare vehicul: fără replay de comandă veche, fără falsă confirmare de întoarcere; alerta vizuală persistentă pentru evenimentul deja confirmat.
8. Oprește sunetul: alertele vizuale rămân; bannerul se poate confirma și închide numai după semnal dry/valid.
9. Teste audio pe G20: mod silențios, volum media 0, ecran blocat, aplicație minimizată, Stealth activ și full-screen sonar.
10. Test pe apă doar după calibrarea sondei și validarea PCB RevF, GPS/HOME, failsafe-urilor H743 și preciziei RTL.

**Nu rula `workflow_dispatch`, nu crea PR și nu face merge în `main` până ce utilizatorul termină lista de modificări.**
