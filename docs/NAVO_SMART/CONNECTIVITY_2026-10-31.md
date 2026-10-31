# NAVO connectivity — implementation and acceptance

The application creates one `NavoConnectivity` backend in Dashboard, independent
of opening Settings. After QGC startup it discovers serial ports, reuses existing
QGC configurations, opens an incoming MAVLink UDP listener on 14550 if needed,
and attempts all eligible saved serial/TCP/UDP connections through LinkManager.
No arming, mode, mission, parameter-write or actuator command is added here.

Settings → General → Conectivitate exposes per-link transport state, received
bytes, recent valid autopilot HEARTBEAT, connect/check controls, saved TCP
endpoints, the baud for unopened NAVO serial configurations, and real sonar and
camera states. Verification observes traffic; it never reconnects a healthy link
or treats an open UDP socket/TCP connection as a live vehicle.

Duplicate endpoints are grouped. Existing links are never closed, replaced or
reconfigured. Automatic attempts back off at 15/30/60/120 seconds and stop after
five attempts per endpoint until a manual retry. Startup uses saved endpoints;
it does not scan 65535 network ports or invent an IP address. Manual connect-all
also attempts the saved auxiliary sonar/camera transports. Sonar replay is
isolated, and the existing per-sonar connect-on-startup preference is respected.
Camera transport and decoded video are reported separately.

## Android and GR01 boundaries

Pinned QGC v5.0.7 explicitly supports only one serial link at a time on Android.
Its LinkManager stops enumerating serial ports once one is connected, to avoid
file-descriptor leakage in the Android serial implementation. NAVO follows that
guard, retains the last inventory and marks other USB connections unavailable
while the serial slot is occupied. TCP/UDP may run alongside it.

GPS/RTK, selected NMEA, bootloader and known system ports are not opened as
MAVLink. Serial baud must match the actual bridge; no live link's baud is changed.

The G20/GR01 vendor SDK is not implemented by this change. If G20 exposes its
radio telemetry as a standard serial endpoint or saved TCP/UDP connection, QGC
can use it. If it requires a proprietary SDK bridge, that adapter remains a
separate hardware integration. The TCP form requires the actual address and
port from the device: neither 127.0.0.1:5760 nor 192.168.43.1:5760 is assumed.
SBUS control and H743 power are independent of MAVLink connectivity.

The NAVO automatic switch controls NAVO's additional connection attempts; QGC's
native autoconnect preferences remain managed in its own Application Settings.

## Source contracts reviewed

- QGC v5.0.7 `src/Comms/LinkManager.h/.cc`: addConfiguration,
  createConnectedLink, links, default UDP reuse and the Android serial guard.
- `LinkConfiguration.h`, `SerialLink.h`, `TCPLink.h`, `UDPLink.h`,
  `QGCSerialPortInfo.h`, `MAVLinkProtocol.h` and `QmlObjectListModel.h`.
- `MAVLinkProtocol::messageReceived` identifies a HEARTBEAT with nonzero system
  ID, a non-GCS type and a valid autopilot value; freshness expires after 6 s.

## Verification and remaining work

- `tests/connection-policy.cpp`: compiled with g++ and passed retry/backoff,
  active-link preservation, heartbeat expiry and clock-order scenarios.
- `tests/connectivity-startup.mjs`: runs the production startup function with
  explicit backends; saved/empty endpoints, replay, opt-out, duplicate prevention,
  UDP, invalid ports and preservation of edited endpoints passed.
- `tests/connectivity-ui.py`: actual production panel with backend doubles;
  per-row dispatch, transport vs heartbeat, endpoint guards, TCP port validation
  and 320/480/800 pixel containment passed.
- Settings navigation and the previous native H743 parameter access were tested
  with the production Settings page. QML syntax parsing passed.

The full C++ QGC adapter has not been compiled in this local environment. A
future authorized Android build must compile it against the pinned upstream,
then confirm app startup/permissions, USB insertion/removal, one-port Android
limit, failed TCP, UDP with random data, HEARTBEAT expiry/recovery and actual
G20/GR01 telemetry with H743 independently powered. No physical hardware was
accessed, and no Android build or merge is authorized by this PR update alone.
