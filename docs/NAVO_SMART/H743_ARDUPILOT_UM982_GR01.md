# H743 / ArduPilot / UM982 / GR01

H743-WING V3 este controlerul critic: ESC/motor, cârmă, cuve, MANUAL/HOLD/AUTO/RTL, misiuni și failsafe. Nano nu intră în calea de comandă servo.

Legături planificate: UM982 dual-antenna la UART/GPS H743; Nano D1/D0 la UART4 prin J18; GR01 SBUS la RC input; GR01 serial/MAVLink la TELEM; servo/ESC direct la ieșirile H743.

Cuvele sunt comandate prin H743/MAVLink; Nano raportează doar PWM observat.

Înainte de cablare se verifică oficial parametrii ArduPilot, SERIAL mapping, UM982 moving-baseline/yaw, RC mapping, failsafe și SERVO outputs. Nicio configurație nu este declarată hardware-validată înainte de test real.
