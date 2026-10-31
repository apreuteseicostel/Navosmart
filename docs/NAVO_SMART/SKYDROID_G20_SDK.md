# G20 / GR01 telemetry through RCSDK

## Implemented path

H743 UART7 (SERIAL1) ↔ GR01 radio ↔ G20 RCSDK 1.9.2 ↔ NAVO SkydroidBridge
↔ NavoSkydroidLink ↔ QGroundControl MAVLinkProtocol / Vehicle.

The adapter uses `RCSDKManager.initSDK` once, `connectToRC`, then
`PipelineManager.createG12G20Pipeline()` and `connectPipeline`. Incoming
`CommListener.onReadData(byte[])` is delivered unchanged to `LinkInterface.bytesReceived`;
QGC's own output is passed to `Pipeline.writeData`. There is no guessed TCP/UDP
endpoint and no attempt to use ttyHS1/ttyHS2 as MAVLink ports. The SDK internally
selects the G20 data transport.

The existing connectivity controller starts the adapter after QGC startup when
its automatic-connection preference is enabled. Automatic device gating requires
Android ARM and G20 in Build.MODEL/DEVICE/PRODUCT. On an unusually branded G20,
pressing Connect on its SDK row explicitly selects it and saves that selection.
ARM-only SDK initialisation is blocked on x86 emulator. A normal Android phone
does not automatically open the G20 SDK. USB and other normal QGC links remain
available and are not reconfigured or disconnected by this adapter.

## Connectivity diagnostics

Settings → General → Connectivity adds `NAVO G20 / GR01 (RCSDK)`:

- RCSDK startup / connection pending;
- controller connected, GR01 channel pending;
- GR01 channel open, no recent autopilot HEARTBEAT;
- H743 confirmed only after QGC parses a real autopilot HEARTBEAT on this link;
- RX delivered to QGC, SDK TX accepted, RX dropped/expired, SDK errors;
- Connect, Verify and Stop. Stop suppresses automatic retries for this session;
  manual Connect resets the retry budget. Stop is not an autopilot HOLD command.

HEARTBEAT freshness is the existing 6-second connectivity policy. SDK channel
state alone never means that the autopilot is connected. SDK TX count means the
SDK accepted bytes; it is not a hardware command acknowledgement.

Five automatic connection attempts use the existing bounded backoff policy. A
new link times out after 20 seconds without the SDK channel. Loss of an established
controller/channel closes that QGC link; subsequent reconnect creates a fresh
session. No stale output is queued or replayed. Incoming chunks are copied,
bounded at 256 KiB and discarded after 1 second if not consumed. Old-session
callbacks cannot deliver bytes into a replacement session. Replay stops only the
owned SDK link and blocks new live connection attempts. Application exit closes
the SDK channel and releases the controller connection.

## Build integration and upstream changes

Official source: https://gitee.com/skydroid/rcsdk-demo
Commit: `d9c6bcab8bb9993cd16f117c01a7601dce10ea6a` (1.9.2).
AAR SHA256: `e5977ba3292246bcee026defdb8563a18adc9d5573fdfb20a6880ee469f0fde2`.
The official AAR has arm64-v8a and armeabi-v7a native libraries; no x86 libraries.
The manufacturer's README says the G12/G20 pipeline uses UDP since SDK 1.7.3
and requires Skydroid Android firmware 20250110 or newer. This is a firmware
build date, not Android API level.

`tools/prepare-skydroid-android.py` downloads the exact vendor AAR, checks its
SHA256, installs the NAVO Java class and adds Kotlin stdlib 1.6.10 to the pinned
QGC Android package. It fails if the expected upstream factory text changes.
It also supports `--sdk-file` for an offline copy, with the same hash check.

The only native QGC change is an Android-only LinkManager factory branch for the
exact reserved configuration name. Its dynamic UDPConfiguration is a descriptor
owned by LinkManager; the matching instance is NavoSkydroidLink, not UDPLink, and
never binds a QGC UDP socket. Other UDP links retain the original factory path.
The configuration is dynamic and not saved as a user UDP endpoint. Builds outside
the supplied workflow must run the preparation script before configuring QGC.

The vendor AAR is not copied into the repository or assigned a NAVO licence.
Its original producer, source revision and download are retained here; use is
based on the manufacturer's SDK integration instructions. The SDK repository
does not declare a general open-source licence. Packaging the SDK does not make
it GPL-licensed NAVO source. Review distribution terms before public release.

## Hardware evidence and remaining validation

The user confirmed live heading/attitude in Skydroid FLY on this G20 with USB data
removed. Independently powered H743, common ground, crossed GR01 RX→TX7 and
TX→RX7, MAVLink2, 115200 and BRD_SER1_RTSCTS Disabled were checked. This validates
the hardware path in FLY, not this new NAVO adapter.

Local validation: production Java adapter compiled against the official 1.9.2
classes.jar (Android API stubs and Kotlin runtime); deterministic production-Java
tests cover device/ABI gating, one-time SDK initialisation, duplicate callbacks,
duplex bytes, bounded/stale RX, send failure, link loss, old callbacks and
idempotent cleanup. Preparation script tested against actual pinned QGC files,
including repeated execution and official download/hash validation. QML panel
and controller regression tests are run separately.

Full QGC C++/JNI compilation, Android package/emulator checks and actual G20 SDK
operation remain CI/device validation. The x86 emulator can validate that the ARM
SDK is not initialised; it cannot prove the proprietary radio transport works.
Close Skydroid FLY, Device Tool and other GCS apps before the G20 test because
the official example warns about port ownership conflicts.

Bench acceptance, without arming or motor operation:
1. Close competing apps, remove USB data, keep H743/GR01 powered.
2. Launch NAVO; the SDK row should progress to MAVLINK LIVE with changing RX,
   and the normal dashboard should show actual H743 data.
3. Tilt H743 gently: confirm attitude updates, without relying on phone compass.
4. Restart NAVO and verify automatic reconnection.
5. Stop/reconnect the SDK row, exercise link loss and replay, verify that no stale
   data becomes live and that USB fallback still works when selected normally.

No automatic mode, arming, mission, servo or parameter commands were added.
