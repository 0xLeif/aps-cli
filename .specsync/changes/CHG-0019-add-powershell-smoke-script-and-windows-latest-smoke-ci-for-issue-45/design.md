---
change: CHG-0019-add-powershell-smoke-script-and-windows-latest-smoke-ci-for-issue-45
artifact: design
---

# Design

Keep `smoke.sh` as the Unix/fledge path. Add `Scripts/smoke.ps1` as a behavioral twin (same assertions, same SecureState opt-in). CI uses `SwiftyLab/setup-swift` on `windows-latest` then runs the PowerShell script against `.build/debug/aps.exe`. Full `swift test` on Windows stays [#46](https://github.com/0xLeif/aps-cli/issues/46).
