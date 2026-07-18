# APS CLI contract introduction

## MODIFIED

### REQUIREMENT REQ-aps-cli-005

`APSError` SHALL cover `unknownKey`, `invalidValue`, `encodingFailed`, `decodingFailed`, and `persistenceFailed`.

Acceptance Criteria
- Each case has an actionable `description`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.

### REQUIREMENT REQ-aps-cli-001

The CLI SHALL expose get, set, watch, dump, keys, and reset over the fixed `DemoKey` schema covering `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps --help` lists those subcommands.
- `DemoKey` includes only those four cases and exposes `storage`, `valueType`, `helpSummary`, and `detail`.

### REQUIREMENT REQ-aps-cli-002

`set` SHALL reject values that cannot parse to the key's type and exit non-zero via `APSError.invalidValue`.

Acceptance Criteria
- Non-integer `counter` values fail with an invalid-value message.
- Non-boolean `flag` values fail with an invalid-value message.
- `APSError.description` names the key and expected type.

### REQUIREMENT REQ-aps-cli-003

Process-local `State` keys SHALL not be required to persist across process boundaries.

Acceptance Criteria
- `counter` and `message` are documented and tested as process-local.
- `flag` (`StoredState`) and `note` (`FileState`) persist across processes after a successful set.

### REQUIREMENT REQ-aps-cli-004

`watch` SHALL print the current value first and flush subsequent distinct values promptly, including cross-process `FileState` writes to `note`.

Acceptance Criteria
- The first emitted line is the current value.
- Non-TTY stdout still surfaces each change without waiting for process exit.
- An external write to `note.json` is observed within one poll interval without relying on AppState's FileState cache.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `DemoKey` | Fixed schema enum (`CaseIterable`, `ExpressibleByArgument`, `Sendable`). |
| `APSError` | Typed CLI/domain errors. |
| `counter` | Int key stored in AppState `State`. |
| `message` | String key stored in AppState `State`. |
| `flag` | Bool key stored in AppState `StoredState`. |
| `note` | String key stored in AppState `FileState`. |
| `unknownKey` | Unknown demo key token. |
| `invalidValue` | Value could not parse for the key type. |
| `encodingFailed` | UTF-8 JSON encode failure. |
| `decodingFailed` | UTF-8 JSON decode failure. |
| `persistenceFailed` | Disk-backed key did not persist after write. |
| `storage` | Human storage kind (`State` / `StoredState` / `FileState`). |
| `valueType` | Human value type (`Int` / `String` / `Bool`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `detail` | One-line description for `keys`. |
| `description` | Actionable error text for humans and ValidationError bridging. |

Command tree (informational): `Aps` is the `@main` root (`ParsableCommand`) with get, set, watch, dump, keys, and reset / reset --all. CLI `boot()` calls `APSPaths.configure()`.
