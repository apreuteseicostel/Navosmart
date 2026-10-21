# Android emulator disk audit — 2026-10-21

## Confirmed evidence

PR #24 head at 23040301bb500d8f5e7af420f18fdb0322f564b4.
GitHub Actions run 39505769006, job 118914169511:
arm64 APK build/sign: success; x86_64 APK build/sign: success.
Android emulator smoke-test step: failure.
The job log at 2026-10-20T23:39:51Z says:
"Your device does not have enough disk space to run avd: navo-smoke".
The signed arm64 APK was uploaded as artifact 12306893992.
The emulator UI smoke test did not pass, so APK runtime acceptance remains pending.

## Minimal isolated CI change to test

After the signed x86_64 APK is verified, but before installing the emulator system
image, preserve build-x86/NAVO_SMART-x86.apk, delete only the disposable x86_64
CMake/Ninja build tree, and restore the APK to the same path.
Optionally remove the cloned qgc source tree and the no-longer-needed Qt Android
cross-compilation toolchains. Verify both APK signatures and print df -h /.
Keep Android emulator smoke-test assertions unchanged.

Do not declare success until Android emulator UI smoke passes at the same SHA.
No hardware tests are claimed. Do not merge to main or enable NAVO_AUTODEV_ENABLED.
