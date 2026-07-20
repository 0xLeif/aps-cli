# aps-cli loud torn FileState reads

## MODIFIED

### REQUIREMENT REQ-aps-cli-005

`APSError` SHALL cover `invalidValue`, `encodingFailed`, `decodingFailed`, `persistenceFailed`, `keychainUnavailable`, and `corruptState`.

Acceptance Criteria
- Each case has an actionable `description`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.
- `corruptState` is used when a FileState file exists but cannot be decoded.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `DemoKey` | Fixed schema enum including `profile`, `secret`, and `profileName`. |
| `ProfileDocument` | Codable `{name, version}` FileState document. |
| `name` | ProfileDocument display name field. |
| `version` | ProfileDocument integer version field. |
| `init` | ProfileDocument memberwise initializer. |
| `APSKeychain` | Well-known Keychain service/account for `secret`. |
| `service` | Reverse-DNS Keychain feature namespace (`dev.leif.aps`). |
| `account` | Keychain account id (`secret`). |
| `secretAccount` | Full account key (`dev.leif.aps/secret`). |
| `APSError` | Typed CLI/domain errors. |
| `counter` | Int key stored in AppState `State`. |
| `message` | String key stored in AppState `State`. |
| `flag` | Bool key stored in AppState `StoredState`. |
| `note` | String key stored in AppState `FileState`. |
| `profile` | ProfileDocument key stored in AppState `FileState`. |
| `secret` | String key stored in AppState `SecureState` (Keychain). |
| `profileName` | String Slice over `ProfileDocument.name`. |
| `invalidValue` | Value could not parse for the key type. |
| `encodingFailed` | UTF-8 JSON encode failure. |
| `decodingFailed` | UTF-8 JSON decode failure. |
| `persistenceFailed` | Disk/Keychain-backed key did not persist after write. |
| `keychainUnavailable` | SecureState unavailable without Apple Security. |
| `corruptState` | FileState file exists but is undecodable (torn write). |
| `corruptStateExitCode` | Exit code 65 (`EX_DATAERR`) for `corruptState`. |
| `storage` | Human storage kind (`State` / `StoredState` / `FileState` / `SecureState` / `Slice`). |
| `valueType` | Human value type (`Int` / `String` / `Bool` / `ProfileDocument`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `detail` | One-line description for `keys`. |
| `description` | Actionable error text for humans and ValidationError bridging. |

### REQUIREMENT REQ-aps-cli-017

When a FileState file for `note`, `profile`, or `profileName` exists but is undecodable, `aps get` / `aps watch` SHALL fail with `corruptState` and exit code 65; `watch --jsonl` SHALL emit one error event before exiting. Missing files still resolve to initials. README SHALL document single-writer / last-writer-wins semantics.

Acceptance Criteria
- Torn `note.json` / `profile.json` never surfaces as the AppState initial value on the direct disk path.
- Exit code is 65 (`EX_DATAERR`) for `corruptState`.
- README documents the multi-process FileState contract.
