# NAVO SMART P0 integration audit — 2026-10-21

Scope: isolated branch only; no merge, hardware validation, or Codex activation.

## Android (PR #24)
Run 39505769006 compiled and signed arm64 and x86_64 APKs, but the emulator failed due to insufficient runner disk space. Artifact 12306893992 is a build artifact, not evidence of successful emulator UI validation. The missing minimal workflow change is to move the verified x86_64 APK from build-x86/ to build/, delete build-x86/ intermediates, verify both APK signatures, check df, and update smoke-test install/badging paths before starting the emulator. Deleting historical Actions artifacts or upgrading GitHub Pro does not increase the ephemeral runner's disk capacity. Workflow write attempt on this branch was rejected by tool safety checks; no new Android CI has run.

## MANUAL/ACRO and H743 sensor validity
Integrated on this isolated branch: NavoFailsafeController.qml checks manualControlActive() and clears pending app GPS/link HOLD/RTL state. NavoDashboard.qml guards failsafeController's HOLD/RTL signals and energy RTL in MANUAL/ACRO. These are app-level protections, not replacements for ArduPilot onboard failsafes.

MISSING P0: NavoDashboard.qml NavoSafetyManager onHoldRequested/onRtlRequested callbacks at lines 696-703 call holdMission()/rtlMission() without checking MANUAL/ACRO. These callbacks bypass the app-side mode guard used for NavoFailsafeController. The production NavoSafetyManager.qml also lacks the independent temperatureValid/waterValid properties, updateWater(), resetVehicle(), and latched-leak behavior from PR #21. In particular, the PR #23 manager clears waterConfirmed on waterDetected=false without verifying water sensor validity, while PR #21 retains a confirmed leak across invalid sensor samples. The hardware safety UI test expects waterValid.

Safety design: distinguish app-initiated automatic mode changes from ArduPilot onboard failsafe actions. Do not disable H743/ArduPilot failsafes. A sensor-invalid state must not be reported as NORMAL; preserve a confirmed water alarm across transient sensor loss. Review whether an emergency thermal/water response should be a pilot-overriding app command: this is a safety policy decision requiring explicit bench acceptance.

## PR #20–23 classification (key differences)
- INTEGRATED (unaccepted): PR #20 missions, sonar replay, journal, offline controls, and alerts in consolidated PR #23.
- INTEGRATED (unaccepted): PR #21 V3 Lua service and hardware test infrastructure.
- REPLACED intentionally: Nano V2 telemetry path by H743 V3 service when V3 profile is selected; preserve V2 compatibility.
- MISSING P0: PR #21 independent waterValid/temperatureValid, resetVehicle, sensor-loss leak latching; missing MANUAL/ACRO checks on safetyManager callbacks.
- MISSING: PR #21 persistence journal species/weightKg and associated tests in PR #23, pending selective restore.
- INTEGRATED/EXTENDED: PR #22 compass and dashboard indicators in PR #23.
- REQUIRES REVIEW: PR #21 HopperBridge duplicate/timeout behavior versus PR #23 H743 link/pending-command improvements; keep both safety guarantees.
- NOT JUSTIFIED/UNNECESSARY: claiming physical hopper ACK, RTL arrival, or substrate classification from software-only tests.

## Codex/GitHub Actions
The opt-in workflow remains disabled. A safe dry run requires review of permissions, protected paths, test commands, and a branch-only manual dispatch with no autonomous push/merge. NAVO_AUTODEV_ENABLED must remain unset/false until explicit user approval.

## Validation gate
Run Qt safety/UI tests, controller regression, Android full CI and emulator UI smoke on the same commit; then separate H743 bench and water tests. No APK runtime or hardware success is claimed.
