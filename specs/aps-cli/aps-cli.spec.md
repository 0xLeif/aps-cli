---
module: aps-cli
version: 16
status: active
files:
  - Sources/aps/Aps.swift
  - Sources/aps/CLIOutput.swift
  - Sources/aps/DemoKey.swift
db_tables: []
depends_on:
  - state-store
---

# APS CLI

## Purpose

`aps` is a small Swift executable that dogfoods AppState outside SwiftUI.
It exposes a fixed demo schema through ArgumentParser subcommands so humans and
agents can get, set, watch, dump, list, and reset typed application state.

## Public API

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
| `storage` | Human storage kind (`State` / `StoredState` / `FileState` / `SecureState` / `Slice`). |
| `valueType` | Human value type (`Int` / `String` / `Bool` / `ProfileDocument`). |
| `helpSummary` | Tab-separated key/type/storage columns for `keys`. |
| `detail` | One-line description for `keys`. |
| `description` | Actionable error text for humans and ValidationError bridging. |

## Invariants

1. The CLI entry point runs on the real main thread so AppState
   `notifyChange()` assertions hold on Linux and macOS.
2. stdout for `get` / `set` / `watch` / `reset <key>` is only the value line(s);
   help and errors use ArgumentParser defaults.
3. `State` keys are process-local; a new process must not be expected to retain
   `counter` or `message`.
4. `watch` must flush each printed value immediately when stdout is not a TTY.
5. `keys` and `--help` do not mutate application state.

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

- Unknown `DemoKey` token: ArgumentParser rejects before `run()`.
- Non-integer `counter` value: `APSError.invalidValue` -> ValidationError.
- Non-boolean `flag` value: `APSError.invalidValue` -> ValidationError.
- `reset` with neither a key nor `--all`: ValidationError.
- `reset` with both a key and `--all`: ValidationError.
- Failed `note` disk persistence: `APSError.persistenceFailed` -> ValidationError.

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
