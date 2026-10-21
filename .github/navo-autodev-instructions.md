# NAVO AutoDev — coding agent contract

You are implementing software for the NAVO SMART Android bait-boat application.
Read `docs/NAVO_SMART/PLAN_MASTER_DEEPER_QUEST.md` first, then inspect the current repository and tests.

Perform exactly ONE small, high-confidence software improvement per execution, following P0 then P1 then P2.
Prioritize genuine missing behavior, safety guards, regression tests, and reproducible sonar replay.
Use the current codebase; do not invent a new architecture or claim hardware acceptance.

Requirements:
- Work ONLY in the checked-out `autodev/implementation` branch.
- NEVER merge, rebase, force-push, or modify `main`.
- Do not change GitHub workflows, agent instructions, access policies, credentials, firmware, PCB, or hardware definitions.
- Do not introduce or expose secrets; do not access network resources other than dependencies already installed by the workflow.
- ArduPilot Rover remains the authority for failsafe, navigation, and motor control.
- No disabling tests, weakening safety checks, or replacing real tests with empty mocks.
- Physical H743/UM982/G20/Kogger and on-water testing is deferred until hardware exists; record those as unvalidated.
- Preserve existing functionality and avoid unrelated refactoring.
- Prefer modifications to `custom/qml/`, `custom/src/`, `custom/kogger_native/`, `tests/`, and `docs/NAVO_SMART/`.
- Add or update an appropriate regression test for each functional change.
- Run `node tests/audit-regressions.mjs` before finishing.
- If a safe change cannot be identified, leave the tree unchanged and explain the blocker in the final output.
- Never claim Android build or hardware verification without the actual evidence.

The GitHub workflow separately checks tests and publishes code changes to the dedicated AutoDev branch.
Your job is to make the smallest correct source change and leave a clear summary.
