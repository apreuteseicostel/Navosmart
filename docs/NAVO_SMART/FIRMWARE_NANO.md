# Firmware Arduino Nano — NAVO SMART V2 E1

Nano este controller auxiliar și monitor. Nu comandă ESC-ul, cârma sau servo-urile cuvelor. Căderea Nano nu trebuie să elimine controlul H743.

Funcții: monitorizare PWM RC/cuve/canal T; baterie A0; NTC A1; apă A2; RGB D4; far D8; poziții D9; buzzer D10; water excitation D11; ACK D12; UART H743 D0/D1.

UART: 57600 8N1, cadru la 500 ms: `$NAVO,1,uptime_ms,battery_mV,temp_c10,water,water_fault,headlight,position,hopper_l,hopper_r,rudder,alarm*CS` + CRLF. Checksum XOR. Servo fields sunt impulsuri măsurate; 0=stale/unavailable.

Reguli: firmware non-blocking; servo monitor=input only; telemetria nu blochează funcțiile locale. Firmware-ul Rev.D existent este baza tehnică și trebuie migrat ca identificare/documentație la V2 E1.


## Comenzi lumini H743 -> Nano

UART-ul este bidirecțional la 57600 8N1. H743 transmite cadre cu checksum XOR:
`$NAVOCMD,1,HEAD,ON|OFF|TOGGLE*CS` și `$NAVOCMD,1,POS,ON|OFF|TOGGLE*CS`.

D8/PB0 comandă etajul farului (far 10 W cu driver propriu, alimentat din 4S); D9/PB1 comandă MOSFET-ul pozițiilor 5 V. Nano nu alimentează sarcinile direct. Starea executată este confirmată prin telemetria existentă `NVHEAD` / `NVPOS`.

NAVO SMART folosește pentru poziții modurile AUTO/ON/OFF; AUTO este implicit și urmărește starea activă a bărcii.
