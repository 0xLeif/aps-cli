---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-028 | `testForcedSeedUsesRegistryTypeStoragePathInitialOutputAndWatch`, `testForcedStringSeedUsesRegistryBoolStoredState`, `testSeedBulkResetSkipsRemovedSeedName`; forced `counter` conversion in `Scripts/smoke.sh` and `Scripts/smoke.ps1` |
| REQ-state-store-021 | `testForcedSeedPathIgnoresAndPreservesFormerData`, `testForcedSeedSliceUsesRegistryParentAndField`, `testDefaultFlagReadsLegacyAppStateDataAndResetPreventsResurrection`, `testForcedFlagDefinitionDisablesLegacyCompatibility` |

- Force `counter` from Int/State to String/FileState with a new path and initial
  value. Prove set, get, reset, dump, watch, and a fresh process use the forced
  entry and emit a JSON string.
- Force a compiled String seed to Bool and prove machine output uses a JSON
  boolean and invalid strings fail.
- Force `note` to a new path and prove the old path is ignored and preserved.
- Redirect `profileName` Slice metadata and prove reads, writes, and reset use
  the current parent and field.
- Remove a seed name and prove seed bulk reset does not recreate it or touch its
  former data.
- Seed only legacy `App/aps.flag`, prove the unchanged default registry entry
  reads it, then reset and prove it cannot reappear.
- Force `flag` away from its default behavioral definition and prove the
  legacy compatibility key is neither read nor removed.
- Run equivalent forced-seed subprocess coverage in `Scripts/smoke.sh` and
  `Scripts/smoke.ps1`.
- Run `fledge lanes run verify`, change verification, and
  `fledge trust verify`, then require macOS, Linux, and Windows GitHub checks.
