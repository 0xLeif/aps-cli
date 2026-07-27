---
spec: state-store.spec.md
---

# Requirements -  State Store

## Functional

### REQ-state-store-001

`StateStore` get/set/reset/dump/watch SHALL cover `profile` in addition to `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `dump` includes a `profile` entry with object value shape.
- `watch` polling for `profile` reads `profile.json` directly.

### REQ-state-store-002

`StateStore` SHALL inject real `APSClock` / `SystemAPSClock` (`now`) and `JSONCoding` (`encodePretty` / `encodeAuto`) dependencies for dump output.

Acceptance Criteria
- `dump` / `dumpRegistered` JSON includes every registered key and a timestamp.
- Dependencies are loaded via `Application.dependency` / `@AppDependency`.
- `recordMutation` accepts a string key name.

### REQ-state-store-003

Writing `flag` SHALL flush UserDefaults so Linux short-lived processes persist StoredState; writing `note` SHALL verify the on-disk value and throw `APSError.persistenceFailed` when persistence fails; `reset` / `resetAll` restore initials.

Acceptance Criteria
- After `set(.flag, "true")`, a new `StateStore` instance observes true.
- After a successful `set(.note, ...)`, `readNoteFromDisk()` returns the same value.
- `reset(.flag)` restores false and flushes.

### REQ-state-store-004

`watchBlocking` SHALL combine Observation with polling that does not depend on a future RunLoop limit date and honor `shouldContinue`; for `note`, polling SHALL read the file directly so cross-process writes are visible despite AppState FileState caching; `parseBool` accepts common truthy/falsey tokens. Existing undecodable FileState files SHALL throw `APSError.corruptState` instead of falling back to AppState initials.

Acceptance Criteria
- In-process `State` mutations are observed.
- External writes to `note.json` are observed without updating AppState's cache.
- `shouldContinue` false stops the loop without requiring Ctrl-C.
- A torn `note.json` during watch throws `corruptState`.

### REQ-state-store-010

`StateStore` SHALL expose `profile` as `FileState<ProfileDocument>` persisted at `profile.json`, with get/set using JSON encoding and disk read-back verification.

Acceptance Criteria
- Valid profile JSON persists and `profileDocument()` matches.
- Invalid profile JSON throws `APSError.invalidValue`.
- Failed disk persistence throws `APSError.persistenceFailed`.

### REQ-state-store-011

`APSPaths.resolve(stateDir:)` SHALL prefer `--state-dir`, then `APS_HOME`, then `~/.aps` when configuring FileState paths from CLI boot.

Acceptance Criteria
- Explicit stateDir wins over environment.
- Missing both returns the default `~/.aps` path.

### REQ-state-store-012

`StateStore` SHALL inject a real `DemoStats` `ObservableObject` dependency consumed via `@ObservedDependency` on Apple platforms, record mutations on successful `set` / `reset`, and expose `statsSnapshot` / `watchStatsBlocking`.

Acceptance Criteria
- After `set(.counter, "1")`, `statsSnapshot().mutationCount` is 1 and `lastMutatedKey` is `counter`.
- `@ObservedDependency(\.stats)` resolves the same instance that records mutations.
- `watchStatsBlocking` emits the current snapshot first, then a distinct snapshot after a mutation.
- A unit test shows Combine observation (`$mutationCount`) fires on dependency mutation.



### REQ-state-store-013

Superseded by REQ-aps-cli-020 (encrypted-file secret store via `SecretStore`; issue #35). Keychain-backed SecureState paths and `keychainUnavailable` were removed from this CLI.

### REQ-state-store-014

`StateStore` SHALL expose `profileName` via Application.slice over profile.name so writes land in the parent FileState profile value.

Acceptance Criteria
- After set(.profileName, "x"), profileDocument().name is "x" and profile.json reflects it.
- get(.profileName) matches the parent name field.

### REQ-state-store-015

Direct disk reads (`readNoteFromDiskIfPresent` / `readProfileFromDiskIfPresent`) SHALL return nil when the file is absent and throw `APSError.corruptState` when the file exists but cannot be decoded.

Acceptance Criteria
- Missing `note.json` yields nil (not an empty-string fallback from a torn decode).
- Undecodable on-disk JSON throws `corruptState` for note and profile.

### REQ-state-store-016

`StateStore` SHALL load or materialize `schema.json`, resolve string key names through the
registry, and support `addKey` / `removeKey` / `dumpRegistered` / string-name
`watchBlocking` for non-seed keys via DynamicKeyStorage. Schema mutations use
`SchemaFileLock`.

Acceptance Criteria
- `loadSchema()` materializes the demo seed when `schema.json` is missing.
- `get(name:)` / `set(name:)` / `reset(name:)` work for seed and user keys.
- `addKey` without force throws `schemaConflict` on duplicates; `removeKey` throws `unknownKey` when missing.
- `dumpRegistered()` includes every registry key.
- `resetAll()` restores seed keys only; `resetAllRegistered()` restores every registry key.

### REQ-state-store-017

`StateStore.addKey` / `removeKey` SHALL hold an exclusive lock on the state-root schema lock file, re-read `schema.json` under that lock, then write. Concurrent adds with distinct names SHALL all persist.

Acceptance Criteria
- Parallel RMW under the lock retains every distinct added key.
- Duplicate add without `--force` still throws `schemaConflict` after a successful peer add.

### REQ-state-store-018

`SecretStore.set` SHALL call unlock (`get`) when an envelope file exists before sealing a new value. Failure SHALL throw `secretUnlockFailed` without replacing the file.

Acceptance Criteria
- After sealing with passphrase A, set with passphrase B throws and leaves bytes unchanged.
- First set on a missing file still succeeds without a prior unlock.

### REQ-state-store-019

FileState and Slice read-modify-write operations on the same state file SHALL use one exclusive cross-process lock, refresh the parent document from disk before writing, and preserve valid parent fields under concurrent CLI writes.

Acceptance Criteria
- Concurrent `profile` and `profileName` writes produce valid JSON and preserve the parent version.
- Dynamic FileState and Slice writes use the same per-file lock.

### REQ-state-store-020

Every schema-controlled filesystem operation SHALL resolve its path through one
validated storage-path abstraction, re-check canonical containment and existing
path components at operation time, and delete only a verified regular leaf
file.

Acceptance Criteria
- Existing directory, symbolic-link, and special-file leaves are rejected
  without mutation.
- Existing symbolic-link ancestors cannot redirect operations outside the
  state root.
- Missing leaf deletion is a successful no-op.
- Complete-schema validation serializes portable collision checks under the
  schema lock.

### REQ-state-store-021

String-key state operations SHALL use one uniform registry dispatch path for
default and user-added names. The resolved entry SHALL select type, storage,
path, initial value, Slice metadata, disk validation, polling, and reset
behavior.

Acceptance Criteria
- A seed name forced to another supported type or adapter uses only the forced
  definition, including its type and storage metadata in both seed and
  registered dumps.
- An unchanged default State seed uses its compiled AppState adapter value in
  the seed dump while retaining type and storage metadata from the registry.
- FileState and EncryptedFile paths come from the current entry.
- Slice reads and writes use the current parent and field.
- The unchanged default flag remains readable from legacy AppState StoredState
  data when no canonical dynamic value exists, and reset prevents resurrection.

### REQ-state-store-022

StateStore reset and purge operations SHALL be transactional for errors
detected before return. Schema purge SHALL acquire the schema lock before the
storage lock, restore the original schema on detected purge failure, and report
rollback failure distinctly. Storage resets SHALL verify their postconditions
before recording success.

Acceptance Criteria
- FileState reset atomically overwrites the initial value under its per-file
  lock without deleting the old file first.
- Secret reset throws, holds `secret.store.lock`, removes and verifies only the
  envelope leaf, and preserves shared `secret.key` material.
- Schema removal plus purge holds `schema.json.lock` through candidate write,
  storage deletion, verification, and any original-schema rollback.
- Registered set and reset operations reload their entry under
  `schema.json.lock` and retain that lock through verified persistence, so a
  stale writer cannot recreate data after successful purge.
- Windows stale-lock recovery never reclaims a valid lock whose owner process
  is alive or cannot be proven dead, regardless of lock age.
- Concurrent APS schema mutation cannot reuse a purged path during the
  transaction.
- Successful rollback rethrows the original operation error; failed rollback
  emits a distinct stable rollback error that truthfully identifies the schema,
  StoredState value, reset FileState file, or staged file that could not be
  restored.
- Bulk reset stops at the first failure, identifies reset, failed, and
  not-attempted keys, and records stats only for successful keys.
- Bulk-reset stats publish only after the outer schema lock is released, on
  both full success and partial-success error paths, so synchronous subscribers
  can safely perform schema operations.
- Parent/Slice compatibility compares an explicitly present parent field and
  Slice initial with type-sensitive `SchemaJSON` equality, while an omitted
  parent field uses the Slice initial fallback.
- Sibling Slice compatibility also compares each Slice's effective field type,
  using the parent object shape when declared and the Slice type otherwise, so
  identical initial JSON cannot hide incompatible reset types.
- StoredState resets restore canonical and legacy backing objects when
  replacement verification fails.
- StoredState rollback verifies exact raw-object restoration and reports
  `rollback_failed` if restoration cannot be synchronized or verified.
- FileState and Slice reset snapshot the exact prior file bytes under the
  storage lock, restore absent or present state after detected write
  verification failure, and report `rollback_failed` if exact restoration
  cannot be verified.
- Registered StoredState set synchronizes and type-checks the canonical object,
  treating a dropped or mistyped write as persistence failure and restoring
  the exact prior object.
- Destructive leaf removal stages the original regular file and restores it
  when post-delete verification fails. Success requires verified absence of
  both the original and staging leaves. The staging leaf uses a bounded,
  hash-based component independent of the original leaf length.
- Failed staged-leaf restoration reports `rollback_failed` instead of masking
  data stranded under the staging name.
- FileState and Slice storage locks derive from the full portable relative path
  and cannot alias `schema.json.lock` or another same-basename storage path.
- Storage-lock acquisition failures report the affected FileState, Slice, or
  encrypted key rather than misidentifying the failure as `schema.json`.
- Slice reads use the Slice entry type when the parent object shape omits the
  field and reject JSON values of another primitive type.
- Slice set and reset use the same declared-type fallback, preserving
  String, Int, Bool, and object values without string coercion.
- Documentation-only edits to a default entry preserve its default adapter
  behavior.
- A default Slice uses its compiled adapter only while its resolved parent also
  behaviorally matches the default parent; replacing the parent selects registry
  storage for the Slice.
- Default flag writes synchronize and verify canonical and legacy values as one
  operation through both typed and string-name entry points, restoring both
  exact prior objects after detected failure.
- Schema removal reloads and compares the candidate before destructive purge,
  then reloads and compares the original after rollback. A dropped schema write
  cannot delete registered storage or hide a failed rollback. Candidate
  write or verification failure restores and verifies the original before
  returning, including when a writer persists and then throws. If that
  restoration fails, the rollback context states that no data purge was
  attempted; rollback after an actual purge failure retains its purge-specific
  context.
- Failed staged deletion verifies that rollback restored a regular-file
  original and removed the staging leaf before returning the deletion error;
  otherwise it reports `rollback_failed`.
- Default FileState reset adapter synchronization reloads the current disk value
  under the storage lock and cannot delete or replace a newer valid write.
- Default adapter synchronization is part of the reset transaction. A
  synchronization failure restores and verifies both the compiled AppState
  adapter cache and the exact pre-reset backing state before returning the
  original error. Bulk reset captures this checkpoint immediately before each
  key so rollback cannot undo an earlier successful key, and stats include only
  those earlier verified successes.
- A failed compiled-adapter restoration reports `rollback_failed` with an
  adapter-specific context that preserves the original synchronization error.
- The default encrypted adapter is a no-op and runs before envelope deletion,
  so an injected adapter failure leaves the exact existing envelope untouched.
