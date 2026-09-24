// NAVOMODEL Rev.D D0.1 hardware / firmware 1.1 candidate.
// Classic Nano ATmega328P, 16 MHz, 5 V only.
#include "Firmware.h"
void setup() { navoBegin(); }
void loop() { navoTick(); }
