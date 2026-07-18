---
spec: aps-cli.spec.md
---

# Requirements -  APS CLI

## Functional

### REQ-aps-cli-001

The fixed demo schema SHALL include `profile` and `secret` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile` and `secret`.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.
- `aps set secret ...` round-trips on macOS through get/dump/reset.

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

`APSError` SHALL cover `invalidValue`, `encodingFailed`, `decodingFailed`, `persistenceFailed`, `keychainUnavailable`, and `corruptState`.

Acceptance Criteria
- Each case has an actionable `description`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.
- `corruptState` is used when a FileState file exists but cannot be decoded.

### REQ-aps-cli-010

`get`, `set`, `dump`, `keys`, and `reset` SHALL support `--json` machine-readable output.

Acceptance Criteria
- JSON payloads are valid UTF-8 JSON objects.
- Typed values preserve Int/Bool where applicable instead of always stringifying.

### REQ-aps-cli-011

Commands that touch FileState SHALL resolve the state directory as `--state-dir`, then `APS_HOME`, then `~/.aps`.

Acceptance Criteria
- `--state-dir` wins over `APS_HOME`.
- When neither is set, FileState lands under `~/.aps`.

### REQ-aps-cli-012

`watch` SHALL support `--count`, `--timeout`, and `--jsonl`.

Acceptance Criteria
- `--count` stops after that many printed values including the initial value.
- `--timeout` stops after the given seconds.
- `--jsonl` emits one JSON object per line.

### REQ-aps-cli-013

The CLI `--version` string SHALL be `0.2.0` while the project is pre-public 0.x.

Acceptance Criteria
- `aps --version` prints `0.2.0`.

### REQ-aps-cli-014

`aps stats` SHALL expose the process-local `DemoStats` ObservedDependency, including optional `--watch` with `--count` / `--timeout`.

Acceptance Criteria
- After `aps set counter 3` in the same process, `aps stats` reports last key `counter`.
- `aps stats --json` includes `mutationCount` and `lastMutatedKey`.
- `aps stats --watch --count 1` exits after printing the initial snapshot.



### REQ-aps-cli-015

`secret` SHALL use a well-named Keychain identity and document headless/CI availability.

Acceptance Criteria
- Keychain account is `dev.leif.aps/secret` (`APSKeychain.secretAccount`).
- `aps reset secret` deletes the Keychain item on macOS.
- README documents macOS Keychain access, Linux unavailability, and headless CI caveats.
- `set secret` on platforms without Security surfaces `keychainUnavailable`.



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

The repository SHALL provide a PowerShell smoke script with the same behavioral coverage as `Scripts/smoke.sh` for FileState / StoredState / keys / stats, and CI SHALL run it on `windows-latest`.

Acceptance Criteria
- `Scripts/smoke.ps1` exercises flag/note/profile persistence, reset, dump, watch, stats, and invalid counter rejection.
- `.github/workflows/windows-smoke.yml` builds the debug binary and runs `Scripts/smoke.ps1` on `windows-latest`.
- `specs/aps-cli/testing.md` and README document both smoke entry points.

