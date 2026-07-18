# state-store loud torn FileState reads

## MODIFIED

### REQUIREMENT REQ-state-store-004

`watchBlocking` SHALL combine Observation with RunLoop polling and honor `shouldContinue`; for `note`, polling SHALL read the file directly so cross-process writes are visible despite AppState FileState caching; `parseBool` accepts common truthy/falsey tokens. Existing undecodable FileState files SHALL throw `APSError.corruptState` instead of falling back to AppState initials.

Acceptance Criteria
- In-process `State` mutations are observed.
- External writes to `note.json` are observed without updating AppState's cache.
- `shouldContinue` false stops the loop without requiring Ctrl-C.
- A torn `note.json` during watch throws `corruptState`.

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

## ADDED

### REQUIREMENT REQ-state-store-015

Direct disk reads (`readNoteFromDiskIfPresent` / `readProfileFromDiskIfPresent`) SHALL return nil when the file is absent and throw `APSError.corruptState` when the file exists but cannot be decoded.

Acceptance Criteria
- Missing `note.json` yields nil (not an empty-string fallback from a torn decode).
- Undecodable on-disk JSON throws `corruptState` for note and profile.
