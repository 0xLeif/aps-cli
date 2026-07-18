---
change: CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
|-------------|----------|
| REQ-aps-cli-001 | `testDemoKeyMetadata`, `testDemoKeyHelpSummaryFormat`, `Scripts/smoke.sh` keys |
| REQ-aps-cli-002 | `testInvalidCounterValue`, `testInvalidFlagValue`, `testAPSErrorDescriptionsAreActionable` |
| REQ-aps-cli-003 | `testProcessLocalStateKeysDoNotClaimCrossProcessPersistence`, `testFlagPersistsAcrossStateStoreInstances`, smoke flag/note |
| REQ-aps-cli-004 | `testWatchDetectsInProcessStateChange`, `testWatchDetectsFileStateChange`, `testWatchDetectsExternalFileStateWrite` |
| REQ-aps-cli-005 | `testAPSErrorDescriptionsAreActionable`, `testInvalidCounterValue` |
| REQ-state-store-001 | `testCounterRoundTrip`, `testMessageAndFlagRoundTrip`, `testNoteFileStateRoundTrip` |
| REQ-state-store-002 | `testDumpIncludesKeysAndUsesDependency`, `testJSONCodingDependency`, `testClockDependencyIsInjectable` |
| REQ-state-store-003 | `testFlagPersistsAcrossStateStoreInstances`, `testResetRestoresInitialValues`, `testResetAll` |
| REQ-state-store-004 | `testWatchDetectsInProcessStateChange`, `testWatchDetectsExternalFileStateWrite`, `testParseBool` |

## Gate evidence

- `swift test` (20 tests)
- `./Scripts/smoke.sh`
- `fledge lanes run verify`
