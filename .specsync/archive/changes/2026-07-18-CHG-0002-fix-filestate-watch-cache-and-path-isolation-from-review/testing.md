---
change: CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
|-------------|----------|
| REQ-aps-cli-004 | `testWatchDetectsExternalFileStateWrite`, `testWatchDetectsFileStateChange` |
| REQ-aps-cli-005 | `testAPSErrorDescriptionsAreActionable` |
| REQ-state-store-001 | `testNoteUsesInjectedFileStatePath`, round-trip tests |
| REQ-state-store-003 | `testNoteFileStateRoundTrip`, `testFlagPersistsAcrossStateStoreInstances` |
| REQ-state-store-004 | `testWatchDetectsExternalFileStateWrite`, `testParseBool` |

## Gate evidence

- `swift test` (20 tests)
- `./Scripts/smoke.sh`
- `fledge lanes run verify`
