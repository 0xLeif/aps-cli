# APS CLI agent-ready 0.2.0 surface

## ADDED

### REQUIREMENT REQ-aps-cli-010

`get`, `set`, `dump`, `keys`, and `reset` SHALL support `--json` machine-readable output.

Acceptance Criteria
- JSON payloads are valid UTF-8 JSON objects.
- Typed values preserve Int/Bool where applicable instead of always stringifying.

### REQUIREMENT REQ-aps-cli-011

Commands that touch FileState SHALL resolve the state directory as `--state-dir`, then `APS_HOME`, then `~/.aps`.

Acceptance Criteria
- `--state-dir` wins over `APS_HOME`.
- When neither is set, FileState lands under `~/.aps`.

### REQUIREMENT REQ-aps-cli-012

`watch` SHALL support `--count`, `--timeout`, and `--jsonl`.

Acceptance Criteria
- `--count` stops after that many printed values including the initial value.
- `--timeout` stops after the given seconds.
- `--jsonl` emits one JSON object per line.

### REQUIREMENT REQ-aps-cli-013

The CLI `--version` string SHALL be `0.2.0` while the project is pre-public 0.x.

Acceptance Criteria
- `aps --version` prints `0.2.0`.

## MODIFIED

### REQUIREMENT REQ-aps-cli-001

The fixed demo schema SHALL include `profile` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile`.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `DemoKey` | Fixed schema enum including `profile`. |
| `ProfileDocument` | Codable `{name, version}` FileState document. |
| `name` | ProfileDocument display name field. |
| `version` | ProfileDocument integer version field. |
| `init` | ProfileDocument memberwise initializer. |
| `APSError` | Typed CLI/domain errors. |
| `counter` | Int key stored in AppState `State`. |
| `message` | String key stored in AppState `State`. |
| `flag` | Bool key stored in AppState `StoredState`. |
| `note` | String key stored in AppState `FileState`. |
| `profile` | ProfileDocument key stored in AppState `FileState`. |
| `unknownKey` | Unknown demo key token. |
| `invalidValue` | Value could not parse for the key type. |
| `encodingFailed` | UTF-8 JSON encode failure. |
| `decodingFailed` | UTF-8 JSON decode failure. |
| `persistenceFailed` | Disk-backed key did not persist after write. |
| `storage` | Human storage kind (`State` / `StoredState` / `FileState`). |
| `valueType` | Human value type (`Int` / `String` / `Bool` / `ProfileDocument`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `detail` | One-line description for `keys`. |
| `description` | Actionable error text for humans and ValidationError bridging. |

Command tree (informational): `Aps` is the `@main` root with get, set, watch, dump, keys, and reset. Shared `StateOptions` expose `--json` and `--state-dir`.
