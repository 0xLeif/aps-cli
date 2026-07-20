# aps-cli TTY-aware output

## MODIFIED

### REQUIREMENT REQ-aps-cli-019

Human output SHALL be TTY-aware under the git porcelain rule: pretty for interactive humans, byte-stable plain text when piped. JSON SHALL be pretty on TTY and compact when piped.

Acceptance Criteria
- Piped `keys` output is the TSV form with no ANSI escapes; TTY gets an aligned table with bold headers and semantic color honoring NO_COLOR.
- `dump` / `--json` payloads are single-line compact JSON off-TTY and pretty on TTY.
- `watch --json` behaves as `--jsonl`; `keys --quiet` prints key names only.
- Shell completion scripts (bash/zsh/fish) are documented in README.

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

Command output modes (informational): human output is TTY-aware (aligned
`keys` table, bold headers, semantic color, NO_COLOR respected); piped output
is byte-stable plain text. JSON is pretty on TTY and compact when piped (gh
rule). `watch --json` is an alias for `--jsonl`; `keys --quiet` prints key
names only. Machine shapes are additive-only contracts; human text may evolve.

### SPEC SECTION Invariants

1. The CLI entry point runs on the real main thread so AppState
   `notifyChange()` assertions hold on Linux and macOS.
2. stdout for `get` / `set` / `watch` / `reset <key>` is only the value line(s);
   help and errors use ArgumentParser defaults. Piped output stays plain:
   no ANSI styling and compact JSON off-TTY.
3. `State` keys are process-local; a new process must not be expected to retain
   `counter` or `message`.
4. `watch` must flush each printed value immediately when stdout is not a TTY.
5. `keys` and `--help` do not mutate application state.
