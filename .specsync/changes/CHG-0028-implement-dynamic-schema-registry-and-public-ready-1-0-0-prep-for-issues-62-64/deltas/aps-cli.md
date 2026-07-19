# aps-cli dynamic schema registry (1.0.0)

## ADDED

### REQUIREMENT REQ-aps-cli-021

`aps key add|remove|list` SHALL mutate or list the state-root `schema.json` registry with stable error codes `schema_invalid` (65), `unknown_key` (64), and `schema_conflict` (64).

Acceptance Criteria
- `aps key add` persists a new entry; without `--force`, a duplicate name fails with `schema_conflict`.
- `aps key remove` drops the entry; `--purge` deletes FileState/EncryptedFile data when present.
- `aps key list` matches the inventory from `aps keys`.

### REQUIREMENT REQ-aps-cli-022

On first use of a state root, aps SHALL materialize a default `schema.json` seed matching the DemoKey inventory; subsequent commands resolve keys by string name from that registry.

Acceptance Criteria
- A fresh `--state-dir` gains `schema.json` after the first keys/get/set/schema call.
- Unknown names fail with `unknown_key` (exit 64).
- Invalid on-disk schema fails with `schema_invalid` (exit 65).

### REQUIREMENT REQ-aps-cli-019

`aps schema` SHALL emit one cacheable JSON document describing the CLI contract: cliVersion, integer schemaVersion (bumped when the document shape changes), state-root precedence, live registered keys, `userSchema` meta (formatVersion, keyCount, hash), commands, payload shapes, and the error table.

Acceptance Criteria
- Output is valid JSON with top-level integer `schemaVersion` equal to 3 after this change.
- Keys cover every entry in the active `schema.json`; commands cover every subcommand including `key`.
- `cliVersion` equals `aps --version`.
- `userSchema.hash` changes when the registry changes.
- Live values stay in `dump`.

## MODIFIED

### REQUIREMENT REQ-aps-cli-001

The default materialized schema SHALL include `profile`, `secret`, and `profileName` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile`, `secret`, and `profileName` on a fresh state root.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.
- `aps set secret ...` round-trips through get/dump/reset.

### REQUIREMENT REQ-aps-cli-005

`APSError` SHALL cover `invalidValue`, `encodingFailed`, `decodingFailed`, `persistenceFailed`, `secretUnlockFailed`, `corruptState`, `schemaInvalid`, `unknownKey`, and `schemaConflict`.

Acceptance Criteria
- Each case has an actionable `description`, stable `code`, and taxonomy `exitCode`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.
- `corruptState` / `schemaInvalid` use exit 65; `unknownKey` / `schemaConflict` use exit 64.

### REQUIREMENT REQ-aps-cli-013

The CLI `--version` string SHALL be `1.0.0`.

Acceptance Criteria
- `aps --version` prints `1.0.0`.
- `aps schema` `cliVersion` equals `1.0.0`.

### SPEC SECTION Purpose

`aps` is a small Swift executable that dogfoods AppState outside SwiftUI.
It exposes a registry-backed schema (`schema.json` under the state root, seeded with
DemoKey defaults) through ArgumentParser subcommands so humans and agents can get,
set, watch, dump, list, reset, and mutate typed application state, and it
self-describes that contract for agents through the `schema` command.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `DemoKey` | Compile-time seed inventory for default schema.json keys. |
| `ProfileDocument` | Codable `{name, version}` FileState document. |
| `name` | ProfileDocument display name field. |
| `version` | ProfileDocument integer version field. |
| `init` | Memberwise / store initializers. |
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
| `UserSchemaDocument` | On-disk schema.json document model. |
| `SchemaKeyEntry` | One registry key entry (name/type/storage/initial/path/slice). |
| `SchemaJSON` | JSON value used for schema initials and object fields. |
| `UserSchema` | Load / materialize / validate / write / hash helpers for schema.json. |
| `fileName` | `schema.json` basename. |
| `currentFormatVersion` | Supported on-disk formatVersion. |
| `namePattern` | Allowed key name regex. |
| `allowedTypes` | Supported value type tokens. |
| `allowedStorage` | Supported storage tokens. |
| `defaultDocument` | Demo seed schema document. |
| `schemaURL` | Path to schema.json under a state root. |
| `loadOrMaterialize` | Load schema.json or write the demo seed when missing. |
| `load` | Decode and validate schema.json. |
| `write` | Validate and atomically persist schema.json. |
| `validate` | Structural checks for schema documents. |
| `isSafeRelativePath` | Rejects absolute / parent-traversal paths. |
| `hash` | Stable SHA256 of canonical schema bytes. |
| `entry` | Lookup a SchemaKeyEntry by name. |
| `formatVersion` | UserSchemaDocument format version field. |
| `namespace` | UserSchemaDocument namespace field. |
| `keys` | UserSchemaDocument key list. |
| `type` | SchemaKeyEntry value type token. |
| `storage` | Human storage kind (`State` / `StoredState` / `FileState` / `EncryptedFile` / `Slice`). |
| `initial` | SchemaKeyEntry initial SchemaJSON. |
| `path` | Relative file path for FileState/EncryptedFile. |
| `doc` | Optional key documentation string. |
| `objectShape` | Field types for object keys. |
| `sliceOf` | Parent key name for Slice entries. |
| `sliceField` | Parent field name for Slice entries. |
| `detail` | One-line description for `keys`. |
| `lifetime` | Process vs persisted lifetime label. |
| `wireString` | SchemaJSON rendered as a CLI wire string. |
| `encode` | SchemaJSON Codable encode. |
| `string` | SchemaJSON string case. |
| `int` | SchemaJSON int case. |
| `bool` | SchemaJSON bool case. |
| `object` | SchemaJSON object case. |
| `invalidValue` | Value could not parse for the key type. |
| `encodingFailed` | UTF-8 JSON encode failure. |
| `decodingFailed` | UTF-8 JSON decode failure. |
| `persistenceFailed` | Disk-backed key or schema.json did not persist after write. |
| `secretUnlockFailed` | Secret store would not open (wrong passphrase or key). |
| `corruptState` | FileState file exists but is undecodable (torn write). |
| `schemaInvalid` | schema.json undecodable or fails validation. |
| `unknownKey` | Name not present in the active registry. |
| `schemaConflict` | key add would overwrite without `--force`. |
| `corruptStateExitCode` | Exit code 65 (`EX_DATAERR`) for corrupt/invalid data. |
| `valueType` | Human value type (`Int` / `String` / `Bool` / `object`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `description` | Actionable error text for humans. |
| `code` | Stable machine error code for the JSON envelope. |
| `exitCode` | sysexits-aligned process exit code. |
| `hint` | Actionable next step in the error envelope. |

Command output modes (informational): human output is TTY-aware (aligned
`keys` table, bold headers, semantic color, NO_COLOR respected); piped output
is byte-stable plain text. JSON is pretty on TTY and compact when piped (gh
rule). `watch --json` is an alias for `--jsonl`; `keys --quiet` prints key
names only. Machine shapes are additive-only contracts; human text may evolve.
Command tree (informational): `Aps` is the `@main` root with get, set, watch,
dump, keys, key, stats, reset, and schema. `schema` prints one cacheable JSON
document (`SchemaDocument`): cliVersion, integer schemaVersion (bumped when the
document shape changes), state-root precedence, live registry keys, userSchema
meta, commands, payload shapes, and the error table. Live state stays in `dump`.

### SPEC SECTION Error Cases

Domain errors fail through a single contract (`CLIOutput.fail`): a human line
on stderr, an optional JSON envelope, and a taxonomy exit code.

Exit codes (sysexits-aligned):

| Code | Meaning | aps mapping |
|------|---------|-------------|
| 0 | success | stdout contract satisfied |
| 64 | EX_USAGE | caller-fixable: bad key/flags, `invalidValue`, `unknownKey`, `schemaConflict`, reset arg conflicts |
| 65 | EX_DATAERR | corrupt persisted state (`corruptState`), undecodable data (`decodingFailed`), or invalid schema (`schemaInvalid`) |
| 70 | EX_SOFTWARE | internal bug: `encodingFailed` |
| 73 | EX_CANTCREAT | write did not persist: `persistenceFailed` |
| 66 | EX_NOINPUT | reserved for future explicit-file operations |

- Missing state files are not errors: they mean the initial value.
- A disk-backed file that exists but does not decode fails loudly (65) via
  `StateStore.requireDecodableDiskState` before `get` / `watch` output.
- With `--json` / `--jsonl`, or when `APS_ERROR_JSON=1`, stderr additionally
  gets one `{"error":{"code","message","hint"}}` envelope; stdout stays empty
  on error in every mode.
- Unknown registry names fail in `run()` with `unknown_key` (64).
