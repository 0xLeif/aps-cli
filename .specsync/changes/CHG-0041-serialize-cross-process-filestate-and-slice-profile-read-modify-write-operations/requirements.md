---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: requirements
---

# Requirements

### REQ-state-store-019

FileState and Slice read-modify-write operations on the same state file use one exclusive cross-process lock, refresh the parent document from disk before writing, and preserve valid parent fields under concurrent CLI writes.
