# Testing -  State Store

- Round-trip tests for each DemoKey seed and registry string-key helpers
- reset and resetAll restore initials
- watchBlocking in-process and FileState change detection
- dump includes dependency-driven timestamp and all keys
- DemoStats ObservedDependency records mutations and Combine publishes on change
- Bulk-reset stats subscribers can reacquire the schema lock on partial failure
  because verified-success publications occur after the outer lock is released
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
- Bulk reset rejects incompatible parent/Slice and sibling Slice initial values,
  including sibling values with identical wire text but distinct SchemaJSON
  types, without falsely reporting overwritten outcomes as successful.
- Bulk reset accepts an omitted parent field when the Slice initial provides
  the observable fallback.
- The seed dump preserves seed ordering while typing forced seed values and
  reporting storage metadata from the resolved registry entry.
- Bulk reset rejects a present integer parent initial when the Slice initial is
  the same wire text represented as a string.
- StoredState reset restores canonical and legacy raw objects after detected
  replacement or synchronization failure; Linux and Windows smoke verify
  cross-process `UserDefaults` persistence.
- Registered StoredState set tests drop a canonical write while synchronization
  succeeds and require persistence failure plus exact prior-object rollback.
- StoredState and staged-file rollback tests inject repeated synchronization,
  dropped restoration-write, and move-back failures and require
  `rollback_failed` with a truthful resource-specific description and hint.
- FileState and Slice reset tests inject post-write verification failures and
  require exact prior-byte restoration; failed restoration reports the reset
  file through `rollback_failed`.
- Storage-lock name tests cover nested `schema.json`, same basenames, and
  portable case-fold aliases.
- Storage-lock acquisition failure tests require the selected key in the
  `persistence_failed` error.
- Bool Slice verification uses the declared parent object shape.
- Unshaped Bool Slice reads use the Slice entry type and reject JSON integer
  values instead of accepting Foundation numeric bridging.
- Unshaped String, Int, Bool, and object Slice set/reset round trips preserve
  their declared JSON types.
- Staged deletion restores FileState and secret envelope data when
  postcondition inspection fails.
- Legacy default-flag fixtures use AppState's JSON-encoded `App/aps.flag`
  representation and verify canonical reset behavior.
- Documentation-only default edits still synchronize the AppState adapter, and
  reset-then-write flag tests require canonical and legacy reads to agree.
- Replacing the default `profile` parent while leaving `profileName` unchanged
  keeps direct Slice writes on the replacement registry file and leaves the
  compiled profile file unchanged.
- Default flag set tests drop the legacy adapter write and require exact
  canonical and legacy rollback.
- Default FileState reset tests inject newer note and profile writes before
  adapter synchronization and require both values to survive.
