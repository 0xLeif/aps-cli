# state-store dynamic schema registry (1.0.0)

## ADDED

### REQUIREMENT REQ-state-store-016

`StateStore` SHALL load or materialize `schema.json`, resolve string key names through the registry, and support `addKey` / `removeKey` / `dumpRegistered` / string-name `watchBlocking` for non-seed keys via DynamicKeyStorage.

Acceptance Criteria
- `loadSchema()` materializes the demo seed when `schema.json` is missing.
- `get(name:)` / `set(name:)` / `reset(name:)` work for seed and user keys.
- `addKey` without force throws `schemaConflict` on duplicates; `removeKey` throws `unknownKey` when missing.
- `dumpRegistered()` includes every registry key.

## MODIFIED

### REQUIREMENT REQ-state-store-002

`StateStore` SHALL inject real `APSClock` / `SystemAPSClock` (`now`) and `JSONCoding` (`encodePretty` / `encodeAuto`) dependencies for dump output.

Acceptance Criteria
- `dump` / `dumpRegistered` JSON includes every registered key and a timestamp.
- Dependencies are loaded via `Application.dependency` / `@AppDependency`.
- `recordMutation` accepts a string key name.

### SPEC SECTION Purpose

`StateStore` is the AppState-facing service used by the CLI. It reads and writes
registry-backed keys (DemoKey seed bindings plus DynamicKeyStorage for user keys),
injects real dependencies with `@AppDependency`, and provides dump / watch / reset
helpers suitable for non-UI use.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `StateStore` | MainActor facade over registry-backed AppState keys. |
| `init` | Loads clock/jsonCoding/stats dependencies without forcing `~/.aps`. |
| `get` | Returns the current string rendering for a demo or registry key. |
| `set` | Parses and writes a demo or registry key value; records a stats mutation. |
| `reset` | Restores one demo or registry key to its initial value; records a stats mutation. |
| `resetAll` | Restores every demo seed key. |
| `resetAllRegistered` | Restores every key in the active schema.json registry. |
| `dump` | JSON snapshot of demo seed keys (pretty on TTY, compact when piped). |
| `dumpRegistered` | JSON snapshot of every registry key. |
| `watchBlocking` | Observation + polling watch loop for demo or string registry keys. |
| `watchStatsBlocking` | Combine + polling watch loop for ObservedDependency stats. |
| `statsSnapshot` | Immutable view of DemoStats counters. |
| `resetStats` | Clears process-local DemoStats counters. |
| `loadSchema` | Load or materialize schema.json for the active state root. |
| `resolve` | Resolve a SchemaKeyEntry by name or throw `unknownKey`. |
| `addKey` | Persist a new or forced-replaced schema entry. |
| `removeKey` | Remove a schema entry; optional purge of persisted data. |
| `stateRoot` | Active FileState / schema.json directory. |
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
| `encodeAuto` | TTY-aware JSON encode helper (pretty on TTY, compact when piped). |
| `DemoStats` | ObservableObject mutation-stats dependency. |
| `mutationCount` | Number of recorded set/reset mutations. |
| `lastMutatedKey` | Raw key name of the latest mutation. |
| `recordMutation` | Increments counters for a string key name. |
| `reset` | Clears DemoStats counters. |
| `DemoStatsSnapshot` | Codable snapshot of DemoStats. |

### SPEC SECTION Invariants

1. All mutating AppState access happens on the main thread / MainActor.
2. Writing `flag` calls `UserDefaults.standard.synchronize()` so Linux flushes
   before process exit.
3. `dumpRegistered()` includes every key in the active schema.json plus an
   ISO-8601 `timestamp`.
4. `watchBlocking` emits the current value first, then subsequent distinct values.
5. Dependencies are real services, not fake stubs used only for wiring demos.
6. `schema.json` write failures surface as `APSError.persistenceFailed`.
