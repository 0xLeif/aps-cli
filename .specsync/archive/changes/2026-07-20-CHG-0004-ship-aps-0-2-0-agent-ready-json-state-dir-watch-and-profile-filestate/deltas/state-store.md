# StateStore agent-ready 0.2.0 surface

## ADDED

### REQUIREMENT REQ-state-store-010

`StateStore` SHALL expose `profile` as `FileState<ProfileDocument>` persisted at `profile.json`, with get/set using JSON encoding and disk read-back verification.

Acceptance Criteria
- Valid profile JSON persists and `profileDocument()` matches.
- Invalid profile JSON throws `APSError.invalidValue`.
- Failed disk persistence throws `APSError.persistenceFailed`.

### REQUIREMENT REQ-state-store-011

`APSPaths.resolve(stateDir:)` SHALL prefer `--state-dir`, then `APS_HOME`, then `~/.aps` when configuring FileState paths from CLI boot.

Acceptance Criteria
- Explicit stateDir wins over environment.
- Missing both returns the default `~/.aps` path.

## MODIFIED

### REQUIREMENT REQ-state-store-001

`StateStore` get/set/reset/dump/watch SHALL cover `profile` in addition to `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `dump` includes a `profile` entry with object value shape.
- `watch` polling for `profile` reads `profile.json` directly.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `StateStore` | MainActor facade over demo AppState keys. |
| `init` | Loads clock/jsonCoding dependencies without forcing `~/.aps`. |
| `get` | Returns the current string rendering for a demo key. |
| `set` | Parses and writes a demo key value. |
| `reset` | Restores one demo key to its initial value. |
| `resetAll` | Restores every demo key. |
| `dump` | Pretty JSON snapshot with typed values. |
| `watchBlocking` | Observation + polling watch loop. |
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
