# aps-cli encrypted-file secret store

## MODIFIED

### REQUIREMENT REQ-aps-cli-005

`APSError` SHALL cover `invalidValue`, `encodingFailed`, `decodingFailed`, `persistenceFailed`, `keychainUnavailable`, and `corruptState`.

Acceptance Criteria
- Each case has an actionable `description`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.
- `corruptState` is used when a FileState file exists but cannot be decoded.

### REQUIREMENT REQ-aps-cli-020

The `secret` key SHALL be backed by an encrypted-file secret store under the state root (ephemeral X25519 + HKDF + ChaCha20-Poly1305 via swift-crypto), with zero interactive prompts in key-file mode and passphrase mode via `APS_SECRET_PASSPHRASE`.

Acceptance Criteria
- `secret` round-trips set/get/reset with ciphertext at rest in `secret.enc`; the key file is mode 0600.
- No Security.framework/Keychain imports; works on macOS and Linux.
- Wrong passphrase fails with `APSError.secretUnlockFailed`; corrupt envelope fails with `APSError.decodingFailed`.
- Passphrase entry is env-var based; an optional TTY getpass prompt exists when `APS_SECRET_USE_PASSPHRASE=1`.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `DemoKey` | Fixed schema enum including `profile`, `secret`, and `profileName`. |
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
| `secret` | String key stored in the encrypted-file secret store (`secret.enc`). |
| `SecretStore` | Encrypted-file store: `get` / `set` / `reset` over `secret.enc`. |
| `hasSecret` | True when a store file exists (missing means initial value). |
| `get` | Decrypt the stored secret; loud corrupt/unlock failures. |
| `set` | Encrypt, persist, and read-back verify. |
| `reset` | Delete `secret.enc`, restoring the initial value. |
| `profileName` | String Slice over `ProfileDocument.name`. |
| `invalidValue` | Value could not parse for the key type. |
| `encodingFailed` | UTF-8 JSON encode failure. |
| `decodingFailed` | UTF-8 JSON decode failure. |
| `persistenceFailed` | Disk-backed key did not persist after write. |
| `secretUnlockFailed` | Secret store would not open (wrong passphrase or key). |
| `corruptState` | FileState file exists but is undecodable (torn write). |
| `corruptStateExitCode` | Exit code 65 (`EX_DATAERR`) for `corruptState`. |
| `storage` | Human storage kind (`State` / `StoredState` / `FileState` / `EncryptedFile` / `Slice`). |
| `valueType` | Human value type (`Int` / `String` / `Bool` / `ProfileDocument`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `detail` | One-line description for `keys`. |
| `description` | Actionable error text for humans and ValidationError bridging. |
