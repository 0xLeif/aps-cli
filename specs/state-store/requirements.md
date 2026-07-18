---
spec: state-store.spec.md
---

# Requirements -  State Store

## Functional

### REQ-state-store-001

`StateStore` get/set/reset/dump/watch SHALL cover `profile` in addition to `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `dump` includes a `profile` entry with object value shape.
- `watch` polling for `profile` reads `profile.json` directly.

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

### REQ-state-store-010

`StateStore` SHALL expose `profile` as `FileState<ProfileDocument>` persisted at `profile.json`, with get/set using JSON encoding and disk read-back verification.

Acceptance Criteria
- Valid profile JSON persists and `profileDocument()` matches.
- Invalid profile JSON throws `APSError.invalidValue`.
- Failed disk persistence throws `APSError.persistenceFailed`.

### REQ-state-store-011

`APSPaths.resolve(stateDir:)` SHALL prefer `--state-dir`, then `APS_HOME`, then `~/.aps` when configuring FileState paths from CLI boot.

Acceptance Criteria
- Explicit stateDir wins over environment.
- Missing both returns the default `~/.aps` path.

### REQ-state-store-012

`StateStore` SHALL inject a real `DemoStats` `ObservableObject` dependency consumed via `@ObservedDependency` on Apple platforms, record mutations on successful `set` / `reset`, and expose `statsSnapshot` / `watchStatsBlocking`.

Acceptance Criteria
- After `set(.counter, "1")`, `statsSnapshot().mutationCount` is 1 and `lastMutatedKey` is `counter`.
- `@ObservedDependency(\.stats)` resolves the same instance that records mutations.
- `watchStatsBlocking` emits the current snapshot first, then a distinct snapshot after a mutation.
- A unit test shows Combine observation (`$mutationCount`) fires on dependency mutation.



### REQ-state-store-013

`StateStore` SHALL expose `secret` as Keychain-backed `SecureState` with account `dev.leif.aps/secret`, verify Keychain read-back after set, and delete the item on reset.

Acceptance Criteria
- Round-trip get/set works on macOS.
- `reset(.secret)` leaves get as "" and removes the Keychain item.
- Without Security, `set(.secret, ...)` throws `APSError.keychainUnavailable`.

