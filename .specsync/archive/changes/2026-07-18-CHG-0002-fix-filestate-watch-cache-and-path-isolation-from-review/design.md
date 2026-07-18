---
change: CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review
artifact: design
---

# Design

Watch polling for `note` uses a direct JSON read of `note.json` under
`FileManager.defaultFileStatePath`, matching AppState's non-Base64 FileState
encoding. In-process `get`/`set` still go through AppState FileState so the
CLI continues to dogfood the library. Path configuration is a CLI boot concern
so tests can inject temp directories.
