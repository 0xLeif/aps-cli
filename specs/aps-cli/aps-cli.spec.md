---
module: aps-cli
version: 24
status: active
files:
  - Sources/aps/Aps.swift
  - Sources/aps/CLIOutput.swift
  - Sources/aps/DemoKey.swift
  - Sources/aps/TTY.swift
  - Sources/aps/WatchTermination.swift
  - Sources/aps/SecretStore.swift
  - Sources/aps/Schema.swift
db_tables: []
depends_on:
  - state-store
---

# APS CLI

## Purpose

`aps` is a small Swift executable that dogfoods AppState outside SwiftUI.
It exposes a fixed demo schema through ArgumentParser subcommands so humans and
agents can get, set, watch, dump, list, and reset typed application state, and
it self-describes that contract for agents through the `schema` command.

## Public API

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
dump, keys, stats, reset, and schema. `schema` prints one cacheable JSON
document (`SchemaDocument`): cliVersion, integer schemaVersion (bumped on any
contract change), state-root precedence, keys, commands, payload shapes, and
the error table. Static contract only; live state stays in `dump`.
| `description` | Actionable error text for humans and ValidationError bridging. |

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

6. `watch` termination is observable in both channels: a terminal
   `{"type":"end","reason":"count|timeout|sigint|sigterm"}` event in `--jsonl`
   mode or a stderr line in human mode, with exit codes 0 (count), 124
   (timeout), 128+signal (130 SIGINT, 143 SIGTERM). The `--jsonl` stream never
   contains non-JSON lines. An unbounded watch prints a one-time stderr hint
   suggesting `--count` / `--timeout`.

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

## Dependencies

- `ArgumentParser` for the command tree
- AppState (via `StateStore`) for typed state and dependencies
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
