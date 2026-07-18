---
module: state-store
version: 17
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
| `StateStore` | MainActor facade over demo AppState keys. |
| `init` | Loads clock/jsonCoding/stats dependencies without forcing `~/.aps`. |
| `get` | Returns the current string rendering for a demo key. |
| `set` | Parses and writes a demo key value; records a stats mutation. |
| `reset` | Restores one demo key to its initial value; records a stats mutation. |
| `resetAll` | Restores every demo key. |
| `dump` | Pretty JSON snapshot with typed values. |
| `watchBlocking` | Observation + polling watch loop for demo keys. |
| `watchStatsBlocking` | Combine + polling watch loop for ObservedDependency stats. |
| `statsSnapshot` | Immutable view of DemoStats counters. |
| `resetStats` | Clears process-local DemoStats counters. |
| `profileDocument` | Typed profile FileState accessor. |
| `profileName` | Slice accessor for ProfileDocument.name. |
| `readNoteFromDisk` | Direct `note.json` read requiring a present decodable file. |
| `readNoteFromDiskIfPresent` | Optional `note.json` read; throws `corruptState` if torn. |
| `readProfileFromDisk` | Direct `profile.json` read requiring a present decodable file. |
| `readProfileFromDiskIfPresent` | Optional `profile.json` read; throws `corruptState` if torn. |
| `requireDecodableDiskState` | Loud-fail helper for CLI get/watch on FileState keys. |
| `parseBool` | Bool token parser for flag values. |
| `APSClock` | Injected clock dependency protocol. |
| `now` | APSClock current instant. |
| `SystemAPSClock` | Date-backed clock. |
| `JSONCoding` | Shared encode helpers for dump output. |
| `encodePretty` | Pretty JSON encode helper. |
| `DemoStats` | ObservableObject mutation-stats dependency. |
| `mutationCount` | Number of recorded set/reset mutations. |
| `lastMutatedKey` | Raw demo key of the latest mutation. |
| `recordMutation` | Increments counters for a demo key. |
| `reset` | Clears DemoStats counters. |
| `DemoStatsSnapshot` | Codable snapshot of DemoStats. |

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
- JSONCoding encode failures surface as `APSError.encodingFailed` when UTF-8
  conversion fails. Profile JSON parse failures surface as `APSError.invalidValue`.

## Dependencies

- AppState (`Application`, `State`, `StoredState`, `FileState`, `@AppDependency`)
- Observation (`withObservationTracking`) for in-process watch delivery
- Foundation (`UserDefaults`, `RunLoop`, `JSONEncoder`)

## Change Log

- 1: Initial StateStore / Application demo-state contract for the aps CLI.
- 2: Explicit export inventory for SpecSync active-contract checks.
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
| 2026-07-18 | CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15: Remove JSONCoding.decode |
| 2026-07-18 | CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15: Remove unreachable APSError.unknownKey and JSONCoding.decode for issue 15 |
| 2026-07-18 | CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38: Loud torn FileState reads + multi-writer docs |
| 2026-07-18 | CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38: Loud torn FileState reads and document multi-writer semantics for issue 38 |
