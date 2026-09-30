# Ethernet / camera

## Network architecture
LAN is independent of critical H743 control. Ethernet transport supports TCP/UDP, reconnect/heartbeat/dataAlive and configurable host/port. Intended network combines sonar transport and front IP camera through a 10/100 switch. A USR-TCP232-ED2 UART/Ethernet bridge has been selected for the serial-to-LAN role where applicable.

If app, switch, camera or sonar fails, H743+UM982+GR01 must retain RC/HOLD/RTL capability.

## Camera target
Waterproof IP Ethernet camera, RTSP/H.264/MJPEG target, front-mounted and named Camera față. PiP on dashboard and fullscreen view. Avoid fisheye distortion when selecting final lens. Actual camera hardware is not yet purchased/validated, so decoding/stream compatibility must be tested with the chosen device.

## Deferred physical work
Do not claim the Kogger-UART/bridge physical topology final until checked against the exact Kogger hardware/protocol. Camera and Kogger physical validation is intentionally last.
