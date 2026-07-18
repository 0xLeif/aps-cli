---
change: CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review
artifact: context
---

# Context

PR review found that `watch note` could not see cross-process writes because
AppState FileState caches on first read. Also `StateStore.init` overwrote
test-injected FileState paths via `APSPaths.configure()`.

## Decisions

- Poll `note` by reading `note.json` directly (bypass AppState cache).
- Move `APSPaths.configure()` to CLI `boot()` only.
- After `set note`, verify on-disk value and throw `persistenceFailed` if mismatched.
