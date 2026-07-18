---
change: CHG-0019-add-powershell-smoke-script-and-windows-latest-smoke-ci-for-issue-45
artifact: context
---

# Context

Issue #45: `Scripts/smoke.sh` is bash/POSIX-only. Add PowerShell smoke and a `windows-latest` workflow so Windows CI can exercise the CLI without a Unix shell.
