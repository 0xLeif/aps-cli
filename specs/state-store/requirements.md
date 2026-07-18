---
spec: state-store.spec.md
---

# Requirements -  State Store

## Functional

### REQ-state-store-001

`StateStore` SHALL read and write demo keys through AppState Application extensions on the main actor via `init`, `get`, and `set`.

Acceptance Criteria
- `get`/`set` round-trip `counter`, `message`, `flag`, and `note`.
- Mutating paths are MainActor-isolated.

### REQ-state-store-002

`StateStore` SHALL inject real `APSClock` / `SystemAPSClock` (`now`) and `JSONCoding` (`encodePretty`, `decode`) dependencies for `dump` output.

Acceptance Criteria
- `dump` JSON includes every `DemoKey` and a timestamp.
- Dependencies are loaded via `Application.dependency` / `@AppDependency`.

### REQ-state-store-003

Writing `flag` SHALL flush UserDefaults so Linux short-lived processes persist StoredState; `reset` / `resetAll` restore initials.

Acceptance Criteria
- After `set(.flag, "true")`, a new `StateStore` instance observes true.
- `reset(.flag)` restores false and flushes.

### REQ-state-store-004

`watchBlocking` SHALL combine Observation with RunLoop polling and honor `shouldContinue`; `parseBool` accepts common truthy/falsey tokens.

Acceptance Criteria
- In-process `State` mutations are observed.
- `FileState` mutations performed during the loop are observed.
- `shouldContinue` false stops the loop without requiring Ctrl-C.

