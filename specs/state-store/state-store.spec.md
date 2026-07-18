---
module: state-store
version: 3
status: active
files:
  - Sources/aps/StateStore.swift
  - Sources/aps/DemoState.swift
  - Sources/aps/Dependencies.swift
db_tables: []
depends_on: []
---

# State Store

## Purpose

`StateStore` is the AppState-facing service used by the CLI. It reads and writes
the fixed demo keys through Application extensions, injects real dependencies
with `@AppDependency`, and provides dump / watch / reset helpers suitable for
non-UI use.

## Public API

| Export | Description |
|--------|-------------|
| `StateStore` | MainActor AppState facade used by the CLI. |
| `APSClock` | Clock protocol for dump timestamps. |
| `SystemAPSClock` | Production `APSClock` backed by `Date()`. |
| `JSONCoding` | Shared pretty JSON helpers. |
| `init` | Configures FileState path and loads clock/jsonCoding dependencies. |
| `get` | Return the string form of a demo key. |
| `set` | Parse and write; throw `APSError.invalidValue` on bad input. |
| `reset` | Restore one key to its AppState initial value. |
| `resetAll` | Restore every demo key. |
| `dump` | Pretty JSON snapshot using `@AppDependency` clock + jsonCoding. |
| `watchBlocking` | Observation + RunLoop poll loop with `shouldContinue`. |
| `parseBool` | Accept true/false/1/0/yes/no/on/off (case-insensitive). |
| `now` | Current `Date` from an `APSClock`. |
| `encodePretty` | Encode an `Encodable` value as pretty UTF-8 JSON text. |
| `decode` | Decode a `Decodable` value from UTF-8 JSON text. |

Application demo surface (informational): `Application.counter` / `message` / `flag` / `note` / `clock` / `jsonCoding`, with `APSPaths.configure()` pointing FileState at `~/.aps`.

## Invariants

1. All mutating AppState access happens on the main thread / MainActor.
2. Writing `flag` calls `UserDefaults.standard.synchronize()` so Linux flushes
   before process exit.
3. `dump()` includes every `DemoKey` plus an ISO-8601 `timestamp`.
4. `watchBlocking` emits the current value first, then subsequent distinct values.
5. Dependencies are real services, not fake stubs used only for wiring demos.

## Behavioral Examples

```
Given a StateStore on a clean Application
When set(.counter, value: "7") then get(.counter)
Then the result is "7".
```

```
Given set(.flag, value: "true")
When a new process constructs StateStore and get(.flag)
Then the result is "true" (StoredState persistence after synchronize).
```

```
Given watchBlocking(.counter, shouldContinue: { seen.count < 2 })
When onChange receives "1" and sets counter to "2"
Then seen equals ["1", "2"].
```

```
Given dump() after setting message to "hi"
When decoding the JSON
Then keys include message with value "hi" and a timestamp field exists.
```

## Error Cases

- `set(.counter, value: "nope")` throws `APSError.invalidValue`.
- `set(.flag, value: "maybe")` throws `APSError.invalidValue`.
- JSONCoding encode/decode failures surface as `APSError.encodingFailed` /
  `decodingFailed` when UTF-8 conversion fails.

## Dependencies

- AppState (`Application`, `State`, `StoredState`, `FileState`, `@AppDependency`)
- Observation (`withObservationTracking`) for in-process watch delivery
- Foundation (`UserDefaults`, `RunLoop`, `JSONEncoder`)

## Change Log

- 1: Initial StateStore / Application demo-state contract for the aps CLI.
- 2: Explicit export inventory for SpecSync active-contract checks.
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
