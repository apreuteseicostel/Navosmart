# Hardware / power / manufacturing

## Boat
Hull about 80×30×20 cm, two hoppers. Motor 4250 800kv; Flycolor 50A water-cooled ESC 2–6S; Li-ion 4S 16,000mAh, 16.8V max; hopper JX6221 ×2; rudder servo 4806.

## NAVO SMART V2 E1 power
Target PCB long/narrow, roughly 105–120 × 50–60 mm after real placement. Integrated 12V and 5V conversion preferred. Far 10 W has own driver and uses protected battery supply. Position lights are 5V, maximum 1A total. Sonar gets filtered 12V only from this PCB; sonar data is Ethernet-side.

5V source budget is total load, not additional per output. Servo power rail/pass-through remains separate from +5V logic; do not parallel BEC sources.

## Manufacturing
JLCPCB-first component selection. Components preferably assembled by JLCPCB and available in their catalog. User requires front-side components only where possible/for this board design. BOM/CPL/Gerber must use correct positive coordinate/orientation conventions. Silkscreen must identify connector functions/pins. Provide accessible test points and edge connectors.

Before release: electrical audit, currents, pin mapping, footprint/orientation and JLC assembly rotation validation. Existing audit found U1 sixth gate mapping error; E1 must correct it before fabrication.
