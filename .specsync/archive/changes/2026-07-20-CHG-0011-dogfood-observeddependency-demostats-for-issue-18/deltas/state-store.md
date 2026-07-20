# StateStore ObservedDependency DemoStats dogfood

## MODIFIED

### REQUIREMENT REQ-state-store-012

`StateStore` SHALL inject a real `DemoStats` `ObservableObject` dependency consumed via `@ObservedDependency` on Apple platforms, record mutations on successful `set` / `reset`, and expose `statsSnapshot` / `watchStatsBlocking`.

Acceptance Criteria
- After `set(.counter, "1")`, `statsSnapshot().mutationCount` is 1 and `lastMutatedKey` is `counter`.
- `@ObservedDependency(\.stats)` resolves the same instance that records mutations.
- `watchStatsBlocking` emits the current snapshot first, then a distinct snapshot after a mutation.
- A unit test shows Combine observation (`$mutationCount`) fires on dependency mutation.

### SPEC SECTION Public API

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
| `readNoteFromDisk` | Direct `note.json` read bypassing cache. |
| `readProfileFromDisk` | Direct `profile.json` read bypassing cache. |
| `parseBool` | Bool token parser for flag values. |
| `APSClock` | Injected clock dependency protocol. |
| `now` | APSClock current instant. |
| `SystemAPSClock` | Date-backed clock. |
| `JSONCoding` | Shared encode/decode helpers. |
| `encodePretty` | Pretty JSON encode helper. |
| `decode` | JSON decode helper. |
| `DemoStats` | ObservableObject mutation-stats dependency. |
| `mutationCount` | Number of recorded set/reset mutations. |
| `lastMutatedKey` | Raw demo key of the latest mutation. |
| `recordMutation` | Increments counters for a demo key. |
| `reset` | Clears DemoStats counters. |
| `DemoStatsSnapshot` | Codable snapshot of DemoStats. |
