# NAVO SMART V3 — PCB RevF (DFM REVIEW)

**Status: NOT RELEASED FOR FABRICATION.** Source: Library archive `NAVO_SMART_V3_RevF_DFM_REVIEW_14OCT2026.zip` (14–15 October 2026). This document records the verified archive inventory and current integration decisions. It does **not** replace the KiCad files or certify assembly.

## Canonical PCB baseline
- 65 × 40 mm, two-layer routed KiCad PCB; 4 × 2.7 mm non-plated mounting holes.
- KiCad source in archive: `cad/NAVO_SMART_V3.kicad_pro`, `cad/NAVO_SMART_V3.kicad_pcb`, local symbol and footprint libraries, schematic sheets.
- 55 logical components, 38 SMT parts; 12 connectors, each 2 or 3 pins.
- Native reports in archive: ERC 0 errors / 0 warnings; DRC 0 violations / 0 unconnected nets (as reported by archive, not independently rerun).
- Manufacturing review Gerbers, drill files, preliminary BOM/CPL and assembly documentation exist. **Do not order** until assembly rotations/polarities and electrical checks are closed.
- RevF DFM: D6/fanout, TP3 and RGB_IN via adjusted; verify D5/D6 and U/Q rotations against JLCPCB assembly preview. User previously corrected U by 90° and Q by 180° manually; these are review inputs, not a blanket rotation rule for every footprint.

## Power architecture — 23 October 2026
- 4S Li-ion, max 16.8 V: ESC 50 A via appropriate main power distribution, Matek H743-WING V3 via its rated input, 10 W headlight via PCB F1/Q1 and its integrated 9–70 V driver.
- External **12 V buck-boost**, provisionally 3 A continuous: GR01, Kogger sonar, 4 MP IP camera, 3-port Ethernet switch, and position lights. Validate real worst-case consumption, inrush and converter thermal rating. Position lights enter V3 PCB via J3 and leave via J4; F2=1 A.
- External **5 V**: UM982 development board (kit input 3–5.5 V per user-supplied specifications), USR serial–Ethernet module (verify exact variant), and **PCB J7 RGB/driver power**. The V3 RGB branch is 5 V, 3 W, F3=1 A. Keep 5 V rail isolated from H743 servo Vx.
- Matek H743 Vx BEC **5 V / 8 A continuous**: two JX PDI-6221MG hopper servos and one JX PDI-4806HB rudder servo; bench test under mechanical load.
- H743 ADC and GPIO inputs are **3.3 V**, not 5 V.

## V3 PCB connectors — from RevF README
| Connector | Pin 1 | Pin 2 | Pin 3 |
|---|---|---|---|
| J1 BAT4S | + battery 12–16.8 V | GND | — |
| J2 FAR | + headlight after fuse | switched headlight negative | — |
| J3 UBEC12 | external +12 V | GND | — |
| J4 POS12 | + position lights after fuse | switched position lights negative | — |
| J5 FAR-CTL | GND | 3.3 V headlight GPIO | — |
| J6 POS-CTL | GND | 3.3 V position GPIO | — |
| J7 RGB-IN | GND | external +5 V | 3.3 V RGB data | 
| J8 RGB-OUT | GND | +5 V after F3 | 5 V RGB data |
| J9 NTC | NTC | GND | — |
| J10 TEMP-FC | GND | +3.3 V from H743 | analog temperature output |
| J11 WATER | water probe excitation | water probe return | — |
| J12 WATER-FC | GND | 3.3 V water excitation GPIO | analog water output |

**Safety:** All GND references are common. Do not externally connect the switched negative of J2/J4 to ground or the MOSFETs will be bypassed. J7 and J10 are **power inputs** to the V3 board. J7 5 V must be present even when RGB LED is not fitted because the MOSFET gate driver depends on it.

## Outstanding release checks
1. Inspect original KiCad source, rerun ERC/DRC with a controlled toolchain and inspect net-to-footprint pin mapping.
2. Review JLCPCB CPL rotation/polarity for U1–U3, Q1/Q2, D5/D6 and all polarized parts; compare against manually corrected assembly preview.
3. Verify external 12 V converter regulation, peak loads and protection; 5 V converter thermal capacity and rail isolation.
4. Confirm H743 pin assignments and ArduPilot parameters before energizing GPIO/ADC/servos.
5. Test water probe EOL 1 MΩ, NTC, lighting, power-up sequence and shorts on the physical prototype.
6. Keep RevF archive, Gerbers, BOM and CPL as a consistent revision set; do not regenerate the routed PCB with `src/board.py`.

## Source artifacts recovered from Library
- `NAVO_SMART_V3_RevF_DFM_REVIEW_14OCT2026.zip` (complete 125-file CAD/reports/manufacturing review package)
- `Gerbers_NAVO_V3_RevF_DFM_REVIEW.zip`
- `BOM_PRELIMINAR.csv`
- `CPL_PRELIMINAR.csv`
- `CPL_NAVO_V3_RevF_ROTATII_PROVIZORII.csv`

**Archive binaries are not included in this Git commit.** The recovered Library files remain the canonical CAD/manufacturing source until uploaded to a GitHub PCB directory with integrity checks. Previous V2 documents remain historical and must not be used as V3 manufacturing instructions.
