---
change: CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review
artifact: plan
---

# Plan

1. Add `freshValue` / `readNoteFromDisk` for watch polling of `note`.
2. Stop configuring FileState paths inside `StateStore.init`; call from `boot()`.
3. Verify note persistence after set; add `APSError.persistenceFailed`.
4. Add tests for external file writes and injected path isolation.
5. Update specs/README to match.
