---
change: CHG-0019-add-powershell-smoke-script-and-windows-latest-smoke-ci-for-issue-45
artifact: plan
---

# Plan

1. Author `Scripts/smoke.ps1` mirroring `smoke.sh`.
2. Add `.github/workflows/windows-smoke.yml`.
3. Document in README, `testing.md`, and `docs/windows-readiness.md`.
4. SpecSync accept with REQ-aps-cli-018.
