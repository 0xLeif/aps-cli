# Testing -  State Store

- Round-trip tests for each DemoKey seed and registry string-key helpers
- reset and resetAll restore initials
- watchBlocking in-process and FileState change detection
- dump includes dependency-driven timestamp and all keys
- DemoStats ObservedDependency records mutations and Combine publishes on change
- watchStatsBlocking detects dependency mutation
- Isolation: hermetic UserDefaults for StoredState `flag`; per-case FileState
  path; `DynamicKeyStorage.resetProcessMemory()` between cases; parallel suite
  via `Scripts/test-parallel.sh`

- Encrypted-file `secret` round-trip / wrong-passphrase `secretUnlockFailed` / corrupt envelope `decodingFailed`.
- Encrypted-file `secret` parallel fresh writes share one atomically created `0600` key file.
- Secret SET unlock-before-rewrite; parallel schema RMW under SchemaFileLock.
- `resetAll` leaves user keys; `resetAllRegistered` clears them.
- Slice `profileName` writes land in parent `profile` FileState.
- `read*FromDiskIfPresent` returns nil when absent and throws `corruptState` when torn.
- `watchBlocking` throws `corruptState` when a FileState file becomes undecodable.
- Subprocess safety suites reject malicious schema paths before reset/purge and
  verify FileState/EncryptedFile deletion touches only the registered leaf.
- Forced seed registry tests cover uniform get, set, reset, disk validation,
  watch polling, dump typing, FileState paths, StoredState types, and Slice
  parent/field selection.
- Seed bulk reset intersects `DemoKey` names with current registry entries,
  skips removed seeds, and preserves non-seed values.
- Registered and direct `DemoKey` mutations hold the schema lock from
  authoritative resolution through verified persistence.
- Windows lock recovery distinguishes live, dead, indeterminate, corrupt, and
  same-process-orphan owners; only proven-dead or safely orphaned locks are
  reclaimed.
- Bulk reset rejects incompatible parent/Slice and sibling Slice initial values
  without falsely reporting overwritten outcomes as successful.
- StoredState reset restores canonical and legacy raw objects after detected
  replacement or synchronization failure; Linux and Windows smoke verify
  cross-process `UserDefaults` persistence.
- Bool Slice verification uses the declared parent object shape.
- Staged deletion restores FileState and secret envelope data when
  postcondition inspection fails.
- Legacy default-flag fixtures use AppState's JSON-encoded `App/aps.flag`
  representation and verify canonical reset behavior.
