---
change: CHG-0020-prove-swift-test-on-windows-latest-and-portable-aps-home-env-tests-for-issue-46
artifact: design
---

# Design

Mirror linux-smoke: `swift test` produces the debug binary, then smoke.ps1 runs. Replace `setenv`/`unsetenv` with `setProcessEnv` using WinSDK `SetEnvironmentVariableA` on Windows. No AppState Package.swift platform change required if SPM already builds.
