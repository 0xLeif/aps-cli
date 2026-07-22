---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: design
---

# Design

Reuse `SchemaFileLock` with a configurable lock filename. `profile` and `profileName` use `profile.json.lock`; dynamic FileState and Slice entries use a lock derived from the parent file. The profile path refreshes its AppState cache from disk while holding the lock before each write.
