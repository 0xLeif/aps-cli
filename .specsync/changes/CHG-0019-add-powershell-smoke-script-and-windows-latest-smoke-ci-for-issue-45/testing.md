---
change: CHG-0019-add-powershell-smoke-script-and-windows-latest-smoke-ci-for-issue-45
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-018 | `Scripts/smoke.ps1`, `.github/workflows/windows-smoke.yml`, `specs/aps-cli/testing.md`, README Tests and smoke / CI sections |

## Suites

- Local: `pwsh ./Scripts/smoke.ps1`
- `fledge lanes run verify` (Unix `Scripts/smoke.sh`)
- CI: `windows-smoke` workflow
