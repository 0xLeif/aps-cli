# APS CLI SecureState secret dogfood

## MODIFIED

### REQUIREMENT REQ-aps-cli-015

`secret` SHALL use a well-named Keychain identity and document headless/CI availability.

Acceptance Criteria
- Keychain account is `dev.leif.aps/secret` (`APSKeychain.secretAccount`).
- `aps reset secret` deletes the Keychain item on macOS.
- README documents macOS Keychain access, Linux unavailability, and headless CI caveats.
- `set secret` on platforms without Security surfaces `keychainUnavailable`.

### REQUIREMENT REQ-aps-cli-001

The fixed demo schema SHALL include `profile` and `secret` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile` and `secret`.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.
- `aps set secret ...` round-trips on macOS through get/dump/reset.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `DemoKey` | Fixed schema enum including `profile` and `secret`. |
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
| `unknownKey` | Unknown demo key token. |
| `invalidValue` | Value could not parse for the key type. |
| `encodingFailed` | UTF-8 JSON encode failure. |
| `decodingFailed` | UTF-8 JSON decode failure. |
| `persistenceFailed` | Disk/Keychain-backed key did not persist after write. |
| `keychainUnavailable` | SecureState unavailable without Apple Security. |
| `storage` | Human storage kind (`State` / `StoredState` / `FileState` / `SecureState`). |
| `valueType` | Human value type (`Int` / `String` / `Bool` / `ProfileDocument`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `detail` | One-line description for `keys`. |
| `description` | Actionable error text for humans and ValidationError bridging. |
