---
module: aps-cli
version: 39
status: active
files:
  - Sources/aps/Aps.swift
  - Sources/aps/CLIOutput.swift
  - Sources/aps/DemoKey.swift
  - Sources/aps/ResetReport.swift
  - Sources/aps/TTY.swift
  - Sources/aps/WatchTermination.swift
  - Sources/aps/SecretStore.swift
  - Sources/aps/PasswordKDF.swift
  - Sources/aps/SecureKeyFile.swift
  - Sources/aps/Schema.swift
  - Sources/aps/SchemaFileLock.swift
  - Sources/aps/UserSchema.swift
  - Sources/aps/KeyCommands.swift
db_tables: []
depends_on:
  - state-store
---

# APS CLI

## Purpose

`aps` is a small Swift executable that dogfoods AppState outside SwiftUI.
It exposes a registry-backed schema (`schema.json` under the state root, seeded with
DemoKey defaults) through ArgumentParser subcommands so humans and agents can get,
set, watch, dump, list, reset, and mutate typed application state, and it
self-describes that contract for agents through the `schema` command.
`schema.json` is authoritative at runtime for default and user-added names;
`DemoKey` defines seed inventory, not CLI dispatch.

## Public API

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
| `SecretStore` | Strict v2 encrypted-file store with legacy reads, passphrase migration, and locked verified writes. |
| `hasSecret` | True when a store file exists (missing means initial value). |
| `get` | Decrypt the stored secret; loud corrupt/unlock failures. |
| `set` | Unlock existing envelope when present, then seal and verify. |
| `reset` | Throwing, locked, postcondition-verified deletion of `secret.enc` that preserves shared key material. |
| `ResetOutcome` | Verified single-key reset result. |
| `ResetFailure` | Stable first-failure details for bulk reset. |
| `BulkResetReport` | Explicit reset, failed, and not-attempted key lists. |
| `BulkResetError` | Throwable partial-progress bulk reset result. |
| `key` | Name associated with a verified reset outcome or failure. |
| `failed` | First stable failure in a bulk reset, or nil on success. |
| `notAttempted` | Selected keys skipped after the first bulk reset failure. |
| `success` | Creates a successful bulk reset report. |
| `report` | Partial-progress report carried by a bulk reset error. |
| `underlying` | Stable APSError that caused a bulk reset failure. |
| `profileName` | String Slice over `ProfileDocument.name`. |
| `UserSchemaDocument` | On-disk schema.json document model. |
| `SchemaKeyEntry` | One registry key entry (name/type/storage/initial/path/slice). |
| `SchemaJSON` | JSON value used for schema initials and object fields. |
| `UserSchema` | Load / materialize / validate / write / hash helpers for schema.json. |
| `SchemaFileLock` | Exclusive cross-process lock helper; Windows retries only lock acquisition and propagates protected-body errors unchanged. |
| `withExclusiveLock` | Run a schema mutation body under the exclusive lock. |
| `fileName` | `schema.json` basename. |
| `currentFormatVersion` | Supported on-disk formatVersion. |
| `namePattern` | Allowed key name regex. |
| `allowedTypes` | Supported value type tokens. |
| `allowedStorage` | Supported storage tokens. |
| `defaultDocument` | Demo seed schema document. |
| `schemaURL` | Path to schema.json under a state root. |
| `loadOrMaterialize` | Load schema.json or write the demo seed when missing. |
| `loadOrMaterializeUnlocked` | Materialize helper for callers that already hold SchemaFileLock. |
| `loadUnlocked` | Decode schema.json without taking SchemaFileLock. |
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
| `unsupportedSecretEnvelope` | Envelope version or recipient mode is not supported by this aps build. |
| `insecureSecretKeyFile` | Key-file ownership, type, or current-user privacy could not be proven. |
| `corruptState` | FileState file exists but is undecodable (torn write). |
| `schemaInvalid` | schema.json undecodable or fails validation. |
| `unknownKey` | Name not present in the active registry. |
| `schemaConflict` | key add would overwrite without `--force`. |
| `RollbackContext` | Identifies the adapter or backing resource whose restoration failed. |
| `adapter` | Rollback context for a compiled AppState adapter restoration failure. |
| `secretEnvelope` | Rollback context for restoration of an encrypted secret envelope. |
| `schema` | Rollback context for a schema registry restoration failure. |
| `schemaCandidate` | Rollback context for restoration after a candidate schema update failed before purge. |
| `storedState` | Rollback context for a StoredState restoration failure. |
| `fileState` | Rollback context for a FileState or Slice-parent reset restoration failure. |
| `stagedFile` | Rollback context for a staged-file restoration failure. |
| `failureDescription` | Context-specific human description of a rollback failure. |
| `rollbackFailed` | An operation failed and its context-specific resource could not be restored. |
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
Command tree (informational): `APSEntrypoint` peels root `--state-dir` then
dispatches to `Aps` with get, set, watch, dump, keys, key, stats, reset, and
schema. `schema` prints one cacheable JSON document (`SchemaDocument`):
cliVersion, integer schemaVersion (bumped when the document shape changes;
currently 5), state-root precedence, live registry keys, userSchema meta,
commands, payload shapes, and the error table. Live state stays in `dump`.
`reset --all` restores seed names that remain registered through their current
entries; `reset --registered` restores every registry key. Bulk resets execute
in schema order and fail fast with an explicit reset, failed, and not-attempted
report.

## Invariants

1. The CLI entry point runs on the real main thread so AppState
   `notifyChange()` assertions hold on Linux and macOS.
2. stdout for `get` / `set` / `watch` / `reset <key>` is only the value line(s);
   stdout stays empty on error; help uses ArgumentParser defaults and domain
   errors use the Error Cases contract (human line plus optional JSON envelope).
   Piped output stays plain: no ANSI styling and compact JSON off-TTY.
3. `State` keys are process-local; a new process must not be expected to retain
   `counter` or `message`.
4. `watch` must flush each printed value immediately when stdout is not a TTY.
5. `keys` and `--help` do not mutate application state.
6. State root: subcommand `--state-dir` > root `--state-dir` > `APS_HOME` > `~/.aps`.
7. EncryptedFile SET never clobbers ciphertext without a successful unlock when a file exists.
8. `watch` handles SIGINT/SIGTERM on a background dispatch queue, so termination
   does not depend on the main thread servicing its run loop; polling waits are
   capped to observe those signals promptly.
9. `watch --timeout` bounds each polling wait by the remaining timeout so a large
   `--interval` cannot delay timeout termination.
10. `watch` termination is observable in both channels: a terminal
   `{"type":"end","reason":"count|timeout|sigint|sigterm"}` event in `--jsonl`
   mode or a stderr line in human mode, with exit codes 0 (count), 124
   (timeout), 128+signal (130 SIGINT, 143 SIGTERM). The `--jsonl` stream never
   contains non-JSON lines. An unbounded watch prints a one-time stderr hint
   suggesting `--count` / `--timeout`.
11. Registry commands never select type, storage, path, initial value, Slice
    metadata, or output typing from a `DemoKey` name match.
12. Detected reset and purge failures never emit success. Storage postconditions
    are verified under the storage lock; schema removal with purge holds the
    schema lock through deletion and restores the original schema on a detected
    failure.
13. Bulk reset records stats only for verified successes and reports the first
    failure plus every remaining not-attempted key.
14. Every new encrypted envelope is v2 and binds decryption to exactly one
    `recipientMode`. Passphrase metadata uses a fresh 16-byte salt and the fixed
    scrypt profile `N=131072`, `r=8`, `p=1`, with 32 output bytes.
15. Envelope shape, canonical base64, decoded field lengths, recipient mode,
    and KDF constants are validated before KDF or key agreement.
16. v2 never falls back between recipient modes. Wrong credentials or mode
    mismatch leave envelope and key-file bytes unchanged.

## Behavioral Examples

```
Given a fresh process
When `aps set counter 3` runs
Then it prints `3` and exits 0.
```

```
Given `aps set note hello` succeeded in process A
When process B runs `aps get note`
Then it prints `hello` (FileState persistence).
```

```
Given `aps set counter nope`
When the command finishes
Then it exits non-zero with an invalid-value error naming `counter` and `Int`.
```

```
Given `aps watch note` is running
When another process runs `aps set note changed`
Then the watcher prints `changed` within one poll interval.
```

## Error Cases

Domain errors fail through a single contract (`CLIOutput.fail`): a human line
on stderr, an optional JSON envelope, and a taxonomy exit code.

Exit codes (sysexits-aligned):

| Code | Meaning | aps mapping |
|------|---------|-------------|
| 0 | success | stdout contract satisfied |
| 64 | EX_USAGE | caller-fixable: bad key/flags, `invalidValue`, `unknownKey`, `schemaConflict`, reset arg conflicts |
| 65 | EX_DATAERR | corrupt data, invalid schema, or `unsupportedSecretEnvelope` |
| 69 | EX_UNAVAILABLE | `secretUnlockFailed`: configured recipient cannot unlock the envelope |
| 70 | EX_SOFTWARE | internal bug: `encodingFailed` |
| 73 | EX_CANTCREAT | persistence or schema rollback did not complete: `persistenceFailed`, `rollbackFailed` |
| 77 | EX_NOPERM | `insecureSecretKeyFile`: key-file privacy cannot be proven |
| 66 | EX_NOINPUT | reserved for future explicit-file operations |

- Missing state files are not errors: they mean the initial value.
- A disk-backed file that exists but does not decode fails loudly (65) via
  `StateStore.requireDecodableDiskState` before `get` / `watch` output.
- With `--json` / `--jsonl`, or when `APS_ERROR_JSON=1`, stderr gets one
  `{"error":{"code","message","hint"}}` envelope. Bulk reset failures add a
  `report` to that envelope. stdout stays empty on error in every mode.
- Unknown registry names fail in `run()` with `unknown_key` (64).

## Dependencies

- `ArgumentParser` for the command tree
- AppState (via `StateStore`) for typed state and dependencies
- apple/swift-crypto `4.0.0..<4.4.0`: `Crypto` plus public `CryptoExtras`
  scrypt; the upper bound preserves the Swift 6.0 tools floor
- Foundation for FileHandle / RunLoop / process paths

## Change Log

- 1: Initial CLI contract for get/set/watch/dump/keys/reset over the fixed demo schema.
- 2: Explicit export inventory for SpecSync active-contract checks (`DemoKey`, `APSError`).
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
| 2026-07-18 | CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review: Fix FileState watch cache and path isolation from review |
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
| 2026-07-18 | CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review: Fix FileState watch cache and path isolation from review |
| 2026-07-18 | CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review: Fix FileState watch cache and path isolation from review |
| 2026-07-18 | CHG-0004-ship-aps-0-2-0-agent-ready-json-state-dir-watch-and-profile-filestate: Ship aps 0.2.0 agent-ready JSON state-dir watch and profile FileState |
| 2026-07-18 | CHG-0011-dogfood-observeddependency-demostats-for-issue-18: ObservedDependency DemoStats dogfood |
| 2026-07-18 | CHG-0012-dogfood-securestate-secret-keychain-demo-key: SecureState secret Keychain dogfood |
| 2026-07-18 | CHG-0013-dogfood-appstate-slice-via-profilename: Slice profileName dogfood |
| 2026-07-18 | CHG-0011-dogfood-observeddependency-demostats-for-issue-18: Dogfood ObservedDependency DemoStats for issue 18 |
| 2026-07-18 | CHG-0012-dogfood-securestate-secret-keychain-demo-key-for-issue-16: Dogfood SecureState secret Keychain demo key for issue 16 |
| 2026-07-18 | CHG-0013-dogfood-appstate-slice-via-profilename-for-issue-17: Dogfood AppState Slice via profileName for issue 17 |
| 2026-07-18 | CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15: Remove unreachable APSError.unknownKey |
| 2026-07-18 | CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15: Remove unreachable APSError.unknownKey and JSONCoding.decode for issue 15 |
| 2026-07-18 | CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38: Loud torn FileState reads + multi-writer docs |
| 2026-07-18 | CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38: Loud torn FileState reads and document multi-writer semantics for issue 38 |
| 2026-07-18 | CHG-0019-add-powershell-smoke-script-and-windows-latest-smoke-ci-for-issue-45: Add PowerShell smoke script and windows-latest smoke CI for issue 45 |
| 2026-07-18 | CHG-0020-prove-swift-test-on-windows-latest-and-portable-aps-home-env-tests-for-issue-46: Prove swift test on windows-latest and portable APS_HOME env tests for issue 46 |
| 2026-07-18 | CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on: Error contract: exit-code taxonomy and JSON error envelope (issue 31, rebuilt on corruptState main) |
| 2026-07-19 | CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on: Error contract: exit-code taxonomy and JSON error envelope (issue 31, rebuilt on corruptState main) |
| 2026-07-19 | CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33: TTY-aware output under the git porcelain rule (issue 33) |
| 2026-07-19 | CHG-0023-watch-signal-handling-and-termination-semantics-issue-34: Watch signal handling and termination semantics (issue 34) |
| 2026-07-19 | CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35: Encrypted-file secret store via swift-crypto (issue 35) |
| 2026-07-19 | CHG-0025-aps-schema-self-describing-contract-endpoint-issue-32: Add aps schema self-describing contract endpoint (issue 32) |
| 2026-07-19 | CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64: Dynamic schema registry and 1.0.0 prep (issues 62-64) |
| 2026-07-19 | CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64: Implement dynamic schema registry and public-ready 1.0.0 prep for issues 62-64 |
| 2026-07-22 | CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations: Serialize cross-process FileState and Slice profile read-modify-write operations |
| 2026-07-23 | CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch: Harden adversarial findings: safer reset, secret SET unlock, root state-dir, schema lock |
| 2026-07-23 | CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes: Recover stale SecretStore keys and serialize fresh encrypted-file writes |
| 2026-07-26 | CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes: Recover stale SecretStore keys and serialize fresh encrypted-file writes |
| 2026-07-26 | CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch: Harden adversarial findings: safer reset, secret SET unlock, root state-dir, schema lock |
| 2026-07-26 | CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for: Prevent schema-controlled paths from deleting or escaping the APS state root for issue 111 |
| 2026-07-27 | CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112: Make schema.json authoritative for built-in and dynamic key names for issue 112 |
| 2026-07-27 | CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113: Make reset and purge transactional and truthfully report failures for issue 113 |
| 2026-07-27 | CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118: Harden passphrase envelopes and existing secret-key validation for issue 118 |
