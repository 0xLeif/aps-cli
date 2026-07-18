# state-store error contract support

## MODIFIED

### REQUIREMENT REQ-state-store-011

`APSPaths.resolve(stateDir:)` SHALL prefer `--state-dir`, then `APS_HOME`, then `~/.aps` when configuring FileState paths from CLI boot.

Acceptance Criteria
- Explicit stateDir wins over environment.
- Missing both returns the default `~/.aps` path.

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
| `readNoteFromDisk` | Direct `note.json` read bypassing cache; corrupt file throws `decodingFailed`. |
| `readProfileFromDisk` | Direct `profile.json` read bypassing cache; corrupt file throws `decodingFailed`. |
| `ensureReadable` | Loud corrupt-state check before `get` / `watch` output. |
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

### SPEC SECTION Error Cases

- `set(.counter, value: "nope")` throws `APSError.invalidValue`.
- `set(.flag, value: "maybe")` throws `APSError.invalidValue`.
- JSONCoding encode failures surface as `APSError.encodingFailed` when UTF-8
  conversion fails. Profile JSON parse failures surface as `APSError.invalidValue`.
- `readNoteFromDisk` / `readProfileFromDisk`: missing or unreadable file throws
  `APSError.persistenceFailed`; an existing file that does not decode throws
  `APSError.decodingFailed` (exit 65 per the CLI error contract).
- `ensureReadable` ignores missing files (initial-value semantics) and throws
  `APSError.decodingFailed` for corrupt `note.json` / `profile.json`.
