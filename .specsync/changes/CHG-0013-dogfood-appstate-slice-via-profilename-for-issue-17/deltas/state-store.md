# state-store Slice profileName dogfood

## ADDED

### REQUIREMENT REQ-state-store-014

`StateStore` SHALL expose `profileName` via Application.slice over profile.name so writes land in the parent FileState profile value.

Acceptance Criteria
- After set(.profileName, "x"), profileDocument().name is "x" and profile.json reflects it.
- get(.profileName) matches the parent name field.

## MODIFIED

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
| `profileName` | Slice accessor for ProfileDocument.name. |
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
