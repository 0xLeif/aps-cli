---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: plan
---

# Plan

1. Extend the existing cross-process lock to accept a per-file lock name.
2. Apply the lock to profile and dynamic FileState/Slice read-modify-write paths.
3. Add smoke coverage and update the canonical state-store contract.
