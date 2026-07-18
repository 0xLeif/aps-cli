# aps

A tiny Swift CLI that [dogfoods](https://github.com/0xLeif/AppState) **AppState** outside SwiftUI: declare typed app state, get/set/watch/dump it, and show dependency injection.

Cross-platform where AppState allows — **macOS** and **Linux** first.

## Commands

```text
aps get <key>
aps set <key> <value>
aps watch <key>          # print on change (Observation + polling)
aps dump                 # print all known state as JSON
aps --help
```

### Demo keys (fixed schema)

| Key | Type | Storage | Lifetime |
| --- | --- | --- | --- |
| `counter` | `Int` | `State` | Process (in-memory) |
| `message` | `String` | `State` | Process (in-memory) |
| `flag` | `Bool` | `StoredState` | Persisted (`UserDefaults`; CLI calls `synchronize()` so Linux flushes) |
| `note` | `String` | `FileState` | Persisted (`~/.aps/note.json`) |

Dynamic / user-declared keys are intentionally out of scope for v1.

### Dependencies

`aps` injects real services with `@AppDependency` / `Application.dependency`:

- **`clock`** — wall clock for dump timestamps
- **`jsonCoding`** — shared `JSONEncoder` helpers for `aps dump`

## Requirements

- Swift 6.0+
- macOS 14+ or Linux (Swift.org toolchain)

## Build & run

```bash
git clone https://github.com/0xLeif/aps-cli.git
cd aps-cli
swift build
swift run aps --help
```

Release build:

```bash
swift build -c release
.build/release/aps dump
```

### Examples

```bash
# In-memory State
swift run aps set counter 3
swift run aps get counter
swift run aps set message "hello from aps"

# Persisted StoredState / FileState
swift run aps set flag true
swift run aps set note "saved across launches"
swift run aps get note

# Inspect everything (uses injected JSONCoding + clock)
swift run aps dump

# Watch for changes (Ctrl+C to stop)
swift run aps watch note --interval 200
```

`watch` uses Swift Observation for in-process updates and polls as a fallback so disk-backed `FileState` / `StoredState` changes can still surface.

## Tests

```bash
swift test
```

## Layout

```text
Package.swift
Sources/aps/          # executable + AppState demo surface
Tests/apsTests/       # parsing + state round-trips
```

## Non-goals (v1)

- No iCloud `SyncState`, Keychain `SecureState`, or SwiftData `ModelState`
- No plugin system, daemon, or network API
- No dynamic schema language — fixed demo keys only

## Related

- [AppState](https://github.com/0xLeif/AppState) — the library this CLI exercises
