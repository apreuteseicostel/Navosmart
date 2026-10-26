# AGENTS.md — NAVO SMART

Repository-wide instructions for Codex and other coding agents. Apply to all work in this repository. Prefer the current code, CI workflows and reviewed project documents over old task summaries.

## Mission and architecture
- NAVO SMART is an Android-focused Qt/QML/C++ ground-control application built as a QGroundControl custom overlay for an ArduPilot Rover/Boat.
- The target boat uses Matek H743-WING V3, UM982 GNSS, GR01/G20 controls, a Kogger sonar path, an IP camera and hopper actuators. Hardware features may still be experimental; inspect the active branch before assuming they exist.
- Preserve upstream QGroundControl/MAVLink responsibilities and onboard ArduPilot failsafes. Do not reimplement safety-critical autopilot behavior in the UI.

## Multi-agent collaboration
1. Inspect open Issues, PRs, branch ancestry and relevant CI runs before starting. Several features live on separate or stacked PR branches and are NOT necessarily in main.
2. Work on a dedicated task branch. Keep commits focused and open a descriptive PR against the correct base. Never force-push, rewrite another agent's branch or clobber unmerged work.
3. Declare the exact affected files and dependencies in the PR. Coordinate overlapping changes via the relevant PR/Issue before editing shared QML controllers, H743 services, mission code or workflows.
4. Preserve earlier accepted behavior unless the task explicitly changes it. Do not merge PRs or modify secrets, repository permissions or branch protections autonomously.
5. Keep GitHub Issues/PRs as the coordination log; record what changed, tests run, exact commit/CI evidence and remaining blockers.

## Hardware and safety boundaries
- Treat mission upload, START/AUTO, HOLD, RTL, rudder, hoppers, lighting, low-battery response and link/GNSS-loss handling as safety-critical.
- Make unknown, stale or invalid sensor/telemetry states explicit. Never convert missing data into a valid reading or an assumed completed actuator action.
- Do not send real hardware commands, energize actuators, change ArduPilot parameters or enable autonomous operation without explicit hardware commissioning and bench-test approval.
- Keep V2 compatibility where relevant while migrating V3 services to the H743; the new design removes the Arduino Nano. Do not presume actual V3 pin maps, ADC calibration, service capabilities or servo behavior have been verified.
- Make UI actions visibly disabled or clearly experimental until their real hardware/backend path is implemented and validated. Do not claim that a simulator proves water safety.

## Testing and evidence
- Run focused regression tests for changed logic. A baseline command on main is: node tests/audit-regressions.mjs.
- Use appropriate tests from tests/firmware/, tests/persistence/, tests/kogger-replay/, tests/sonar-performance/ and tests/android/ when affected.
- Review .github/workflows/android.yml and .github/workflows/navo-core.yml for the authoritative build/test steps; report results for the exact PR head commit.
- Never call Android successful based only on local unit tests, an earlier build, or an unrelated green commit. Verify APK build and emulator/device tests as applicable, or report them pending/blocked.
- For sonar, mission, replay and persistence changes, test malformed inputs, disconnections, restarts and safe failure paths as well as happy paths.

## Source and licensing
- Preserve copyrights and license notices. Evaluate Kogger upstream GPL-3.0 obligations before copying/adapting code; document exact upstream revision and dependencies.
- Do not silently replace pinned QGroundControl or third-party dependency revisions.

## Completion report
Summarize the branch and PR, files changed, implemented behavior, tests/CI with exact results, unverified hardware assumptions and next safe action. Never describe an untested feature as production-ready.
