# Android FPV Player integration

## Evidence and scope
The user's tests on 2 November 2026 found the same artifacts with TCP and UDP through G20/GR01; direct Ethernet produced clean synchronized video. This rules out neither RF throughput/loss nor receiver/decoder behavior. No claim that a new decoder fixes RF loss is made.

Official source: https://gitee.com/skydroid/fpv-player-demo at b4974344020b85d7eafccdeeec2acc419be453dd. The SDK README prescribes FPVWidget start/stop, usingMediaCodec, rtspTranstype and rcType. The actual 3.3.9 AAR API was inspected and the NAVO Java adapter compiled against official Android 35 and vendor classes. No demo source is copied. prepare-fpv-android.py verifies the SHA256 of FPV Player 3.3.9 and sky-ijkplayer 1.1, downloads the vendor binaries only for the Android build, and preserves the existing RCSDK 1.9.2.

## Behavior
Android ARM RTSP uses FPVWidget with ONLY_SKY, matching the official Java demo. Hardware/Software and RTSP TCP/UDP are saved under NavoEthernet/cameraDecoder and cameraRtspTransport. Hardware means MediaCodec requested, not independent proof of the actual codec selected by the device. The engine stays fixed for A/B tests. Desktop and MJPEG retain Qt Multimedia; those FPV-specific options do not control Qt's decoder.

The Android TextureView lives only inside the QML video rectangle. Qt supplies screen coordinates scaled by device pixel ratio and ancestor clipping. PiP/fullscreen close controls occupy a separate header outside the native view. SDK and view operations run on the Android main looper. Close immediately invalidates the session, fences pending starts/late callbacks, stops the SDK and removes its view. Hidden pages, fullscreen handoff and app suspension release the surface. Returning to a visible explicitly requested view may start a new session; X clears the request, including PiP when fullscreen is closed. No second SDK reconnect loop is added.

Only a recent decoded-YUV callback or TextureView buffer presentation marks video LIVE. The SDK surface listener is forwarded unchanged; MediaCodec direct-to-surface playback does not require a YUV readback. An RTSP connection or encoded-frame callback alone does not. The status includes requested decoder, dimensions and decoded-frame count. Frame freshness is not end-to-end latency. Credentials/URLs are not logged by the NAVO adapter.

## Verification
- Java adapter lifecycle regression: pending start cancelled before UI dispatch, old callbacks ignored, HW/SW and transport forwarded, connection/encoded input cannot assert decoded freshness, native view removed on stop.
- Qt production wrapper, PiP and fullscreen lifecycle: autostart, X/no reopen, fullscreen handoff, no simultaneous visible playback, 236–900 pixel widths.
- Existing Ethernet/settings/persistence, mission, Stealth and controller regression suites remain required.
- Android APK build must pass for the PR head. Host tests do not exercise vendor native decoding or Android TextureView layering.

## G20 acceptance (requires physical controller)
1. Use one fixed RTSP URL and camera stream profile. In Settings > Connections > Camera select Hardware and TCP, save, start video.
2. Repeat with Software, same URL/profile/transport. Record visible artifacts, decoder status and responsiveness. Do not change bitrate/resolution between these two runs.
3. Film a clock/stopwatch in view of the camera together with the G20 screen to measure actual latency; the app cannot infer this from local frame age.
4. On the map: tap PiP for fullscreen, close X; check both native image and PiP disappear and stay stopped. Reopen explicitly. Change pages and scroll the Settings preview; video must not cover tabs or close controls.
5. Interrupt/restore the camera or GR01 link while playback is requested: observe reconnect and only fresh decoded frames returning LIVE. Repeat after explicitly closing: the player must remain absent.
6. Repeat foreground/background and orientation tests. Verify video does not mask modal dialogs; native Android surface composition still requires this physical-device check.
