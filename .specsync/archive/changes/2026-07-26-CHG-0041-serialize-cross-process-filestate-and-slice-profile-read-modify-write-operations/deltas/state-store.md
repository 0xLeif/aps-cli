# state-store concurrent FileState and Slice writes

## ADDED

### REQUIREMENT REQ-state-store-019

FileState and Slice read-modify-write operations on the same state file SHALL use one exclusive cross-process lock, refresh the parent document from disk before writing, and preserve valid parent fields under concurrent CLI writes.

Acceptance Criteria
- Concurrent `profile` and `profileName` writes produce valid JSON and preserve the parent version.
- Dynamic FileState and Slice writes use the same per-file lock.
