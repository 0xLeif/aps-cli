# aps-cli error contract: exit taxonomy and JSON envelope

## MODIFIED

### REQUIREMENT REQ-aps-cli-002

`set` SHALL reject values that cannot parse to the key's type and exit non-zero via `APSError.invalidValue`. All domain errors SHALL follow the error contract: human line on stderr, taxonomy exit code, and a JSON envelope when `--json` / `--jsonl` or `APS_ERROR_JSON=1`.

Acceptance Criteria
- Non-integer `counter` values fail with an invalid-value message.
- Non-boolean `flag` values fail with an invalid-value message.
- `APSError.description` names the key and expected type.
- Exit codes: 64 usage, 65 corrupt or undecodable persisted state, 69 unavailable, 70 internal, 73 write did not persist.
- The envelope shape is `{"error":{"code","message","hint"}}` with stable snake_case codes (`invalid_value`, `encoding_failed`, `decoding_failed`, `persistence_failed`, `keychain_unavailable`, `corrupt_state`); stdout stays empty on error.

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
| `description` | Actionable error text for humans. |
| `code` | Stable machine error code for the JSON envelope. |
| `exitCode` | sysexits-aligned process exit code. |
| `hint` | Actionable next step in the error envelope. |

### SPEC SECTION Invariants

1. The CLI entry point runs on the real main thread so AppState
   `notifyChange()` assertions hold on Linux and macOS.
2. stdout for `get` / `set` / `watch` / `reset <key>` is only the value line(s);
   stdout stays empty on error; help uses ArgumentParser defaults and domain
   errors use the Error Cases contract (human line plus optional JSON envelope).
3. `State` keys are process-local; a new process must not be expected to retain
   `counter` or `message`.
4. `watch` must flush each printed value immediately when stdout is not a TTY.
5. `keys` and `--help` do not mutate application state.

### SPEC SECTION Error Cases

Domain errors fail through a single contract (`CLIOutput.fail`): a human line
on stderr, an optional JSON envelope, and a taxonomy exit code.

Exit codes (sysexits-aligned):

| Code | Meaning | aps mapping |
|------|---------|-------------|
| 0 | success | stdout contract satisfied |
| 64 | EX_USAGE | caller-fixable: bad key/flags, `invalidValue`, reset arg conflicts |
| 65 | EX_DATAERR | corrupt persisted state (`corruptState`) or undecodable data (`decodingFailed`) |
| 69 | EX_UNAVAILABLE | `keychainUnavailable` on platforms without Apple Security |
| 70 | EX_SOFTWARE | internal bug: `encodingFailed` |
| 73 | EX_CANTCREAT | write did not persist: `persistenceFailed` |
| 66 | EX_NOINPUT | reserved for future explicit-file operations |

- Missing state files are not errors: they mean the initial value.
- A disk-backed file that exists but does not decode fails loudly (65) via
  `StateStore.requireDecodableDiskState` before `get` / `watch` output.
- With `--json` / `--jsonl`, or when `APS_ERROR_JSON=1`, stderr additionally
  gets one `{"error":{"code","message","hint"}}` envelope; stdout stays empty
  on error in every mode.
- Unknown `DemoKey` token and flag shape errors: ArgumentParser rejects
  before `run()` with its own 64.
