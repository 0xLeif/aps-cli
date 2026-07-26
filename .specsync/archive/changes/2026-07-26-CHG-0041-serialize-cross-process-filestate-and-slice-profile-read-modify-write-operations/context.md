---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: context
---

# Context

Concurrent CLI processes can read the same parent FileState document before a Slice or FileState write. The existing schema lock does not protect `profile.json`, allowing stale read-modify-write operations to lose fields.
