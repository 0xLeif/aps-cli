---
change: CHG-0004-ship-aps-0-2-0-agent-ready-json-state-dir-watch-and-profile-filestate
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-001 | `testDemoKeyMetadata`, `Scripts/smoke.sh` (`keys` lists profile) |
| REQ-aps-cli-010 | `testCLIOutputTypedValues`, `testDumpIncludesKeysAndUsesDependency`, `Scripts/smoke.sh` (`--json`) |
| REQ-aps-cli-011 | `testAPSPathsResolveOrder`, `Scripts/smoke.sh` (`--state-dir` override) |
| REQ-aps-cli-012 | `testWatchCountBoundStopsLoop`, `Scripts/smoke.sh` (`watch --count`) |
| REQ-aps-cli-013 | `Scripts/smoke.sh` (`aps --version` equals `0.2.0`) |
| REQ-state-store-001 | `testProfileStructuredFileStateRoundTrip`, `testResetAll` |
| REQ-state-store-010 | `testProfileStructuredFileStateRoundTrip`, `testInvalidProfileJSON` |
| REQ-state-store-011 | `testAPSPathsResolveOrder` |

## Suites

- `swift test` (25 tests)
- `./Scripts/smoke.sh`
