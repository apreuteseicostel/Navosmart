# H743 bridge setup

The Nano emits the checksummed NAVO v1 ASCII frame at 57600 baud. The Matek H743 reads it on a port configured for ArduPilot Scripting and republishes validated fields as standard MAVLink NAMED_VALUE_FLOAT messages. NAVO SMART consumes those MAVLink messages; it does not open the Nano UART directly.

## H743 parameters
For the physical UART wired to Nano RX/TX:
- SERIALx_PROTOCOL = 28 (Scripting)
- SERIALx_BAUD = 57 (57600)
- SCR_ENABLE = 1

Place `navo_nano_bridge.lua` in `APM/scripts/` on the H743 SD card and reboot. If this is the first Scripting serial port, the script uses `serial:find_serial(0)`.

## MAVLink names
NVBATV, NVBATTEMP, NVWATER, NVWFAULT, NVHEAD, NVPOS, NVHOPL, NVHOPR, NVRUD, NVALARM.

The bridge validates the Nano XOR checksum before publishing. The ground link remains the normal H743 MAVLink2 link to GR01/G20/QGroundControl.
