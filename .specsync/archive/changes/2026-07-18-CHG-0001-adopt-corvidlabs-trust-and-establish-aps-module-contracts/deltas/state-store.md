# State Store contract introduction

## MODIFIED

### REQUIREMENT REQ-state-store-001

`StateStore` SHALL read and write demo keys through AppState Application extensions on the main actor via `init`, `get`, and `set`, without overwriting an injected `FileManager.defaultFileStatePath`.

Acceptance Criteria
- `get`/`set` round-trip `counter`, `message`, `flag`, and `note`.
- Mutating paths are MainActor-isolated.
- `init` loads dependencies only; CLI `boot()` (or tests) configure FileState paths.

### REQUIREMENT REQ-state-store-002

`StateStore` SHALL inject real `APSClock` / `SystemAPSClock` (`now`) and `JSONCoding` (`encodePretty`, `decode`) dependencies for `dump` output.

Acceptance Criteria
- `dump` JSON includes every `DemoKey` and a timestamp.
- Dependencies are loaded via `Application.dependency` / `@AppDependency`.

### REQUIREMENT REQ-state-store-003

Writing `flag` SHALL flush UserDefaults so Linux short-lived processes persist StoredState; writing `note` SHALL verify the on-disk value and throw `APSError.persistenceFailed` when persistence fails; `reset` / `resetAll` restore initials.

Acceptance Criteria
- After `set(.flag, "true")`, a new `StateStore` instance observes true.
- After a successful `set(.note, ...)`, `readNoteFromDisk()` returns the same value.
- `reset(.flag)` restores false and flushes.

### REQUIREMENT REQ-state-store-004

`watchBlocking` SHALL combine Observation with RunLoop polling and honor `shouldContinue`; for `note`, polling SHALL read the file directly so cross-process writes are visible despite AppState FileState caching; `parseBool` accepts common truthy/falsey tokens.

Acceptance Criteria
- In-process `State` mutations are observed.
- External writes to `note.json` are observed without updating AppState's cache.
- `shouldContinue` false stops the loop without requiring Ctrl-C.

### SPEC SECTION Public API

| Export | Description |
|--------|-------------|
| `StateStore` | MainActor AppState facade used by the CLI. |
| `APSClock` | Clock protocol for dump timestamps. |
| `SystemAPSClock` | Production `APSClock` backed by `Date()`. |
| `JSONCoding` | Shared pretty JSON helpers. |
| `init` | Loads clock/jsonCoding dependencies without forcing `~/.aps`. |
| `get` | Return the string form of a demo key. |
| `set` | Parse and write; throw `APSError.invalidValue` or `persistenceFailed` on failure. |
| `reset` | Restore one key to its AppState initial value. |
| `resetAll` | Restore every demo key. |
| `dump` | Pretty JSON snapshot using `@AppDependency` clock + jsonCoding. |
| `watchBlocking` | Observation + RunLoop poll loop; `note` polls via direct disk read. |
| `parseBool` | Accept true/false/1/0/yes/no/on/off (case-insensitive). |
| `now` | Current `Date` from an `APSClock`. |
| `encodePretty` | Encode an `Encodable` value as pretty UTF-8 JSON text. |
| `decode` | Decode a `Decodable` value from UTF-8 JSON text. |
| `readNoteFromDisk` | Read `note.json` without touching AppState's FileState cache. |

Application demo surface (informational): `Application.counter` / `message` / `flag` / `note` / `clock` / `jsonCoding`. `APSPaths.configure()` is invoked from CLI `boot()`, not `StateStore.init`.
