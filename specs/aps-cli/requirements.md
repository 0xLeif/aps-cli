---
spec: aps-cli.spec.md
---

# Requirements -  APS CLI

## Functional

### REQ-aps-cli-001

The default materialized schema SHALL include `profile`, `secret`, and `profileName` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile`, `secret`, and `profileName` on a fresh state root.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.
- `aps set secret ...` round-trips through get/dump/reset.

### REQ-aps-cli-002

`set` SHALL reject values that cannot parse to the key's type and exit non-zero via `APSError.invalidValue`.

Acceptance Criteria
- Non-integer `counter` values fail with an invalid-value message.
- Non-boolean `flag` values fail with an invalid-value message.
- `APSError.description` names the key and expected type.

### REQ-aps-cli-003

Process-local `State` keys SHALL not be required to persist across process boundaries.

Acceptance Criteria
- `counter` and `message` are documented and tested as process-local.
- `flag` (`StoredState`) and `note` (`FileState`) persist across processes after a successful set.

### REQ-aps-cli-004

`watch` SHALL print the current value first and flush subsequent distinct values promptly, including cross-process `FileState` writes to `note`.

Acceptance Criteria
- The first emitted line is the current value.
- Non-TTY stdout still surfaces each change without waiting for process exit.
- An external write to `note.json` is observed within one poll interval without relying on AppState's FileState cache.

### REQ-aps-cli-005

`APSError` SHALL cover `invalidValue`, `encodingFailed`, `decodingFailed`, `persistenceFailed`, `secretUnlockFailed`, `corruptState`, `schemaInvalid`, `unknownKey`, and `schemaConflict`.

Acceptance Criteria
- Each case has an actionable `description`, stable `code`, and taxonomy `exitCode`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.
- `corruptState` / `schemaInvalid` use exit 65; `unknownKey` / `schemaConflict` use exit 64.

### REQ-aps-cli-010

`get`, `set`, `dump`, `keys`, and `reset` SHALL support `--json` machine-readable output.

Acceptance Criteria
- JSON payloads are valid UTF-8 JSON objects.
- Typed values preserve Int/Bool where applicable instead of always stringifying.

### REQ-aps-cli-011

Commands that touch FileState SHALL resolve the state directory as `--state-dir` (accepted
before the subcommand or on the subcommand), then `APS_HOME`, then `~/.aps`. A subcommand
`--state-dir` wins over a peeled root `--state-dir`.

Acceptance Criteria
- `aps --state-dir PATH get note` uses PATH.
- `aps get note --state-dir PATH` still works.
- Subcommand `--state-dir` overrides a root `--state-dir` when both are present.
- When neither is set, FileState lands under `~/.aps`.

### REQ-aps-cli-012

`watch` SHALL support `--count`, `--timeout`, and `--jsonl`.

Acceptance Criteria
- `--count` stops after that many printed values including the initial value.
- `--timeout` stops after the given seconds.
- `--jsonl` emits one JSON object per line.

### REQ-aps-cli-013

The CLI `--version` string SHALL be `1.0.0`.

Acceptance Criteria
- `aps --version` prints `1.0.0`.
- `aps schema` `cliVersion` equals `1.0.0`.

### REQ-aps-cli-014

`aps stats` SHALL expose the process-local `DemoStats` ObservedDependency, including optional `--watch` with `--count` / `--timeout`.

Acceptance Criteria
- After `aps set counter 3` in the same process, `aps stats` reports last key `counter`.
- `aps stats --json` includes `mutationCount` and `lastMutatedKey`.
- `aps stats --watch --count 1` exits after printing the initial snapshot.



### REQ-aps-cli-015

Superseded by REQ-aps-cli-020 (encrypted-file secret store; issue #35). The Keychain-backed SecureState demo was removed because ad-hoc CLI signatures cannot earn durable Keychain trust.

### REQ-aps-cli-016

`profileName` SHALL read and write `ProfileDocument.name` through an AppState `Slice` over `profile`.

Acceptance Criteria
- `aps set profileName X` updates the parent `profile` document name on disk.
- `aps get profileName` returns the current parent name field.
- `aps keys` lists `profileName` with storage `Slice`.

### REQ-aps-cli-017

When a FileState file for `note`, `profile`, or `profileName` exists but is undecodable, `aps get` / `aps watch` SHALL fail with `corruptState` and exit code 65; `watch --jsonl` SHALL emit one error event before exiting. Missing files still resolve to initials. README SHALL document single-writer / last-writer-wins semantics.

Acceptance Criteria
- Torn `note.json` / `profile.json` never surfaces as the AppState initial value on the direct disk path.
- Exit code is 65 (`EX_DATAERR`) for `corruptState`.
- README documents the multi-process FileState contract.

### REQ-aps-cli-018

The repository SHALL provide a PowerShell smoke script with the same behavioral coverage as `Scripts/smoke.sh` for FileState / StoredState / keys / stats, and CI SHALL run `swift test` plus that smoke script on `windows-latest`.

Acceptance Criteria
- `Scripts/smoke.ps1` exercises flag/note/profile persistence, reset, dump, watch, stats, and invalid counter rejection.
- `.github/workflows/windows-smoke.yml` runs `swift test` then `Scripts/smoke.ps1` on `windows-latest` (Swift 6.3.1+).
- `APS_HOME` resolution tests mutate the process environment with a portable helper (not POSIX-only `setenv`).
- `specs/aps-cli/testing.md` and README document the Windows test + smoke path.


### REQ-aps-cli-020

The encrypted-file SecretStore SHALL serialize fresh `set` key recovery or
creation, sealing, atomic envelope persistence, and read-back verification
through `secret.store.lock`. If no `secret.enc` exists, an invalid stale
`secret.key` SHALL be removed before creating a replacement. Direct missing or
invalid key access SHALL use `secret.key.lock`, while valid existing-key reads
SHALL not require that lock. Passphrase-mode writes SHALL ignore stale
`secret.key` paths. Existing-envelope SET SHALL preserve persistence failures
from unreadable or missing envelopes while translating invalid-key failures to
`secretUnlockFailed`.

Acceptance Criteria
- Fresh and parallel SecretStore SET operations remain serialized and leave a decryptable envelope.
- Invalid stale key material is recovered only when no envelope exists.
- Existing-envelope persistence failures remain `persistenceFailed`; invalid keys surface `secretUnlockFailed`.

### REQ-aps-cli-021

`aps key add|remove|list` SHALL mutate or list the state-root `schema.json` registry with stable error codes `schema_invalid` (65), `unknown_key` (64), and `schema_conflict` (64).

Acceptance Criteria
- `aps key add` persists a new entry; without `--force`, a duplicate name fails with `schema_conflict`.
- `aps key remove` drops the entry; `--purge` deletes FileState/EncryptedFile data when present.
- `aps key list` matches the inventory from `aps keys`.

### REQ-aps-cli-022

On first use of a state root, aps SHALL materialize a default `schema.json` seed matching the DemoKey inventory; subsequent commands resolve keys by string name from that registry.

Acceptance Criteria
- A fresh `--state-dir` gains `schema.json` after the first keys/get/set/schema call.
- Unknown names fail with `unknown_key` (exit 64).
- Invalid on-disk schema fails with `schema_invalid` (exit 65).

### REQ-aps-cli-023

`aps reset --all` SHALL restore only DemoKey seed keys. `aps reset --registered` SHALL restore every key in the active `schema.json` registry. Passing both, or a key with either flag, SHALL fail with a validation error.

Acceptance Criteria
- After `key add` + `set`, `reset --all` leaves the user key value unchanged.
- `reset --registered` restores that user key to its initial value.
- JSON payloads use `"reset":"all"` for `--all` and `"reset":"registered"` for `--registered`.

### REQ-aps-cli-024

`aps schema` SHALL advertise root-or-subcommand `--state-dir`, reset `--registered`, and bump integer `schemaVersion` to 4 for this contract shape change.

Acceptance Criteria
- `aps schema` emits `"schemaVersion":4`.
- The `reset` command entry lists flags including `--registered`.

### REQ-aps-cli-019

`aps schema` SHALL emit one cacheable JSON document describing the CLI contract: cliVersion, integer schemaVersion (bumped when the document shape changes), state-root precedence, live registered keys, `userSchema` meta (formatVersion, keyCount, hash), commands, payload shapes, and the error table.

Acceptance Criteria
- Output is valid JSON with top-level integer `schemaVersion` equal to 4 after this change.
- Keys cover every entry in the active `schema.json`; commands cover every subcommand including `key`.
- `cliVersion` equals `aps --version`.
- `userSchema.hash` changes when the registry changes.
- Live values stay in `dump`.

### REQ-aps-cli-025

The shared file lock helper SHALL support exclusive locks for each state file
used by a read-modify-write operation, while preserving the existing schema
lock API.

Acceptance Criteria
- Schema mutations continue to use `schema.json.lock`.
- FileState and Slice writes can serialize on `profile.json.lock`.

### REQ-aps-cli-026

When no `secret.enc` envelope exists, a fresh SecretStore SET SHALL recover an
invalid stale `secret.key` before creating replacement key material. The fresh
SET operation SHALL remain serialized by `secret.store.lock`.

Acceptance Criteria
- A partial `secret.key` does not make the first fresh SET fail with
  `persistenceFailed`.
- A successful recovery leaves a valid key and decryptable envelope.
- A `secret.key` directory is never removed during recovery, and a corrupt
  existing key with an envelope surfaces `secretUnlockFailed`.
