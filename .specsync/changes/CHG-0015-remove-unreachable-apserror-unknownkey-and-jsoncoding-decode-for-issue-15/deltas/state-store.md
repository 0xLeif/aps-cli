# state-store remove JSONCoding.decode

## MODIFIED

### REQUIREMENT REQ-state-store-002

`StateStore` SHALL inject real `APSClock` / `SystemAPSClock` (`now`) and `JSONCoding` (`encodePretty`) dependencies for `dump` output.

Acceptance Criteria
- `dump` JSON includes every `DemoKey` and a timestamp.
- Dependencies are loaded via `Application.dependency` / `@AppDependency`.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `StateStore` | MainActor AppState facade for demo keys. |
| `init` | Loads clock, jsonCoding, stats (and keychain when available). |
| `now` | Injected clock timestamp. |
| `statsSnapshot` | Current DemoStats counters. |
| `resetStats` | Clears DemoStats counters. |
| `get` | String view of a demo key. |
| `set` | Parse and write a demo key. |
| `reset` | Restore one demo key to its initial value. |
| `resetAll` | Reset every demo key. |
| `dump` | Pretty JSON snapshot via JSONCoding.encodePretty. |
| `watchBlocking` | Observation + polling watch loop. |
| `watchStatsBlocking` | ObservedDependency stats watch loop. |
| `profileDocument` | Typed profile FileState accessor. |
| `profileName` | Slice accessor for ProfileDocument.name. |
| `readNoteFromDisk` | Direct `note.json` read bypassing cache. |
| `readProfileFromDisk` | Direct `profile.json` read bypassing cache. |
| `parseBool` | Truthy/falsey token parser. |
| `APSClock` | Clock dependency protocol. |
| `SystemAPSClock` | Date-backed clock. |
| `JSONCoding` | Shared encode helpers for dump output. |
| `encodePretty` | Pretty JSON encode helper. |
