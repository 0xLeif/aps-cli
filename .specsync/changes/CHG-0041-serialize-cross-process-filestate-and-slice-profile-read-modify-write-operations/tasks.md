---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: tasks
---

# Tasks

- [x] Generalize the cross-process lock for per-file state locks.
- [x] Serialize profile FileState and Slice writes with a shared lock.
- [x] Lock dynamic FileState and Slice writes.
- [x] Add the concurrent CLI smoke regression and update state-store requirements.
