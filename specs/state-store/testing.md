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

- Encrypted-file tests prove strict v2 mode metadata, fresh 16-byte passphrase
  salts, fixed scrypt bounds, key-file KDF omission, and stable unsupported,
  malformed, credential, mode-mismatch, and insecure-key errors.
- Legacy passphrase fixtures prove successful one-way migration, wrong-password
  byte preservation, exact rollback after replacement failure, and
  `rollback_failed` when restoration cannot be proven.
- Legacy key-file fixtures read without mutation and upgrade only on the next
  successful set.
- Counting-KDF tests prove one derivation per validated salt inside an operation
  and no repeated scrypt or decrypt work for unchanged encrypted-watch polls.
- Encrypted-file parallel fresh writes share one exclusively created private
  key file.
- POSIX key-file tests cover exact `0600`, safe handle-based repair, no-follow
  symlink rejection, directories, FIFOs, hostile umask, exclusive-create races,
  and refusal to regenerate unsafe paths.
- Windows key-file tests cover private create/load/remove, current-user DACL
  repair and revalidation, and wrong-kind handle rejection.
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
  including sibling values with identical SchemaJSON initials but different
  effective types on an unshaped parent field, without falsely reporting
  overwritten outcomes as successful.
- Bulk reset accepts an omitted parent field when the Slice initial provides
  the observable fallback.
- The seed dump preserves seed ordering while typing forced seed values and
  reporting storage metadata from the resolved registry entry.
- The seed dump reads unchanged default State values from their live AppState
  adapters after typed `set` operations.
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
- Staged deletion requires both the original and staging leaves to be absent
  before success and restores the original when staged unlink is dropped.
- Legacy default-flag fixtures use AppState's JSON-encoded `App/aps.flag`
  representation and verify canonical reset behavior.
- Documentation-only default edits still synchronize the AppState adapter, and
  reset-then-write flag tests require canonical and legacy reads to agree.
- Replacing the default `profile` parent while leaving `profileName` unchanged
  keeps direct Slice writes on the replacement registry file and leaves the
  compiled profile file unchanged.
- Default flag set tests drop the legacy adapter write and require exact
  canonical and legacy rollback through typed and string-name entry points.
- Schema removal tests drop the candidate write before purge and the original
  write during rollback, requiring safe refusal and `rollback_failed`
  respectively. Candidate verification mismatch and read-failure tests require
  verified original restoration or a candidate-specific `rollback_failed`
  that states no purge was attempted; rollback after a purge failure retains
  purge-specific wording. A write-then-throw fault preserves its diagnostic
  after verified restoration.
- Staged deletion tests drop or replace the rollback move and require a
  regular-file original plus an absent staging leaf before restoration succeeds.
- Default FileState reset tests inject newer note and profile writes before
  adapter synchronization and require both values to survive.
- Default-adapter reset tests inject failures after note and profile-name
  synchronization and require exact backing bytes, compiled cache restoration,
  per-key bulk checkpoints, and successful-key-only stats.
- Adapter reset rollback tests inject a failed restoration proof and require a
  resource-specific `rollback_failed`; encrypted adapter failure preserves the
  exact pre-reset envelope because synchronization precedes deletion.
