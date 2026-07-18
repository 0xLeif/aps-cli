---
module: aps-cli
version: 1
status: draft
files:
  - Sources/aps/Aps.swift
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

### Command tree

`Aps` is the `@main` root (`ParsableCommand`).

| Command | Role |
|---------|------|
| `get <key>` | Print the current string form of a demo key. |
| `set <key> <value>` | Parse and write a value, then print the stored form. |
| `watch <key>` | Print the current value, then print again on each change. |
| `dump` | Print all demo keys as pretty JSON (uses injected coding + clock). |
| `keys` | List demo keys with type, storage kind, and a short description. |
| `reset <key>` | Restore one key to its initial value and print it. |
| `reset --all` | Restore every demo key. |

### Demo keys (`DemoKey`)

| Key | Type | Storage |
|-----|------|---------|
| `counter` | `Int` | `State` (process-local) |
| `message` | `String` | `State` (process-local) |
| `flag` | `Bool` | `StoredState` (UserDefaults) |
| `note` | `String` | `FileState` (`~/.aps/note.json`) |

`DemoKey` is `CaseIterable`, `ExpressibleByArgument`, and `Sendable`.

### Errors

`APSError` covers unknown keys, invalid values, and coding failures. CLI `set`
surfaces invalid values as ArgumentParser `ValidationError` messages.

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

## Dependencies

- `ArgumentParser` for the command tree
- AppState (via `StateStore`) for typed state and dependencies
- Foundation for FileHandle / RunLoop / process paths

## Change Log

- 1: Initial CLI contract for get/set/watch/dump/keys/reset over the fixed demo schema.
