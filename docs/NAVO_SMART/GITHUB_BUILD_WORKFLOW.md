# GitHub / build working rules

## Mainline
Goal is one authoritative main. Do not blind-merge old feature branches. Compare unique differences and classify as INTEGRATED / REPLACED BY BETTER / MISSING -> INTEGRATE / NO LONGER NEEDED.

## Build discipline
Before every code change, inspect newest main Actions run and HEAD.
- failed: inspect actual log and fix the first blocking error with the smallest technically correct change;
- running: do not stack speculative commits; read-only audit is allowed;
- green: verify APK artifact and Android package/signature/SDK/ABI checks when available, then continue the agreed next batch.

Group coherent UI corrections rather than one build per icon. Never claim hardware validation from emulator/build success.

## Historical checkpoints
PR #3 contained a large older integration and required controlled recovery rather than raw merge. PR #7 was the isolated Batimetrie HD line and was also to be integrated selectively.

Known stable checkpoint before this documentation branch: main commit edca893c7fddf68c337ccedb547af7ab9d8454c1, Android build #635 GREEN. This is historical, not a substitute for checking the latest run.
