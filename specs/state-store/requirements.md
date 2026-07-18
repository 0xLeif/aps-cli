---
spec: state-store.spec.md
---

# Requirements -  State Store

## Functional

### REQ-state-store-001

`StateStore` SHALL read and write demo keys through AppState Application extensions on the main actor via `init`, `get`, and `set`, without overwriting an injected `FileManager.defaultFileStatePath`.

Acceptance Criteria
- `get`/`set` round-trip `counter`, `message`, `flag`, and `note`.
- Mutating paths are MainActor-isolated.
- `init` loads dependencies only; CLI `boot()` (or tests) configure FileState paths.

### REQ-state-store-002

`StateStore` SHALL inject real `APSClock` / `SystemAPSClock` (`now`) and `JSONCoding` (`encodePretty`, `decode`) dependencies for `dump` output.

Acceptance Criteria
- `dump` JSON includes every `DemoKey` and a timestamp.
- Dependencies are loaded via `Application.dependency` / `@AppDependency`.

### REQ-state-store-003

Writing `flag` SHALL flush UserDefaults so Linux short-lived processes persist StoredState; writing `note` SHALL verify the on-disk value and throw `APSError.persistenceFailed` when persistence fails; `reset` / `resetAll` restore initials.

Acceptance Criteria
- After `set(.flag, "true")`, a new `StateStore` instance observes true.
- After a successful `set(.note, ...)`, `readNoteFromDisk()` returns the same value.
- `reset(.flag)` restores false and flushes.

### REQ-state-store-004

`watchBlocking` SHALL combine Observation with RunLoop polling and honor `shouldContinue`; for `note`, polling SHALL read the file directly so cross-process writes are visible despite AppState FileState caching; `parseBool` accepts common truthy/falsey tokens.

Acceptance Criteria
- In-process `State` mutations are observed.
- External writes to `note.json` are observed without updating AppState's cache.
- `shouldContinue` false stops the loop without requiring Ctrl-C.

