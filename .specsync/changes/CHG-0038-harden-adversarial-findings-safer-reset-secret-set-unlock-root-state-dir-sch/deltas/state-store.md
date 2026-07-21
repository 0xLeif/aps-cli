# state-store harden adversarial findings

## ADDED

### REQUIREMENT REQ-state-store-017

`StateStore.addKey` / `removeKey` SHALL hold an exclusive lock on the state-root schema
lock file, re-read `schema.json` under that lock, then write. Concurrent adds with
distinct names SHALL all persist.

Acceptance Criteria
- Parallel RMW under the lock retains every distinct added key.
- Duplicate add without `--force` still throws `schemaConflict` after a successful peer add.

### REQUIREMENT REQ-state-store-018

`SecretStore.set` SHALL call unlock (`get`) when an envelope file exists before sealing a
new value. Failure SHALL throw `secretUnlockFailed` without replacing the file.

Acceptance Criteria
- After sealing with passphrase A, set with passphrase B throws and leaves bytes unchanged.
- First set on a missing file still succeeds without a prior unlock.

## MODIFIED

### REQUIREMENT REQ-state-store-016

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

### SPEC SECTION Invariants

1. All mutating AppState access happens on the main thread / MainActor.
2. Writing `flag` calls `UserDefaults.standard.synchronize()` so Linux flushes
   before process exit.
3. `dumpRegistered()` includes every key in the active schema.json plus an
   ISO-8601 timestamp.
4. `watchBlocking` emits the current value first, then subsequent distinct values.
5. Dependencies are real services, not fake stubs used only for wiring demos.
6. `schema.json` write failures surface as `APSError.persistenceFailed`.
7. Schema RMW (add/remove/materialize-on-missing) is serialized by `SchemaFileLock`.
8. `SecretStore.set` never replaces an existing envelope without a successful unlock.
