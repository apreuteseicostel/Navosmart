# NAVO SMART V2 E1 — PCB

## Contract
Li-ion 4S max 16.8 V; Nano clasic 5 V detașabil; surse 12 V și 5 V integrate; poziții 5 V max 1 A; far 10 W cu driver propriu; sonar alimentat 12 V filtrat.

## Pinout Nano V2
D0 RX=UART din H743; D1 TX=UART spre H743; D2=RC_A_N; D3=RC_B_N; D4=RGB_TX; D5=MON_L_N; D6=MON_R_N; D7=MON_T_N; D8=HEAD_CTL; D9=POS_CTL; D10=BUZZ_CTL; D11=WATER_EXC; D12=ACK_N; A0=BAT_ADC; A1=TEMP_ADC; A2=WATER_ADC.

D5/D6/D7 sunt monitorizare PWM, nu ieșiri servo.

## Servo pass-through
J7/J8=H743_L/SERVO_L; J9/J10=H743_R/SERVO_R; J11/J12=H743_T/SERVO_T. V_SERVO separat de +5V_LOGIC.

## J18 H743 UART
1 GND; 2 TX_TO_H743; 3 RX_FROM_H743; 4 +5V H743 opțional prin JP4. U5/U6 SN74LVC1T45 fac translatarea UART. JP4 selectează sursa fără paralelizare directă.

## Audit deschis
Raportul V2 a identificat maparea greșită a porții a șasea U1. Se corectează în schema/PCB E1 înainte de fabricație, nu în firmware. Footprint-urile și rotațiile JLCPCB se validează separat.
