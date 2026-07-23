---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: research
---

# Research

The existing `SchemaFileLock` already provides process-local and POSIX/Windows cross-process exclusion. Reusing it avoids a second lock implementation; a separate lock filename prevents profile data operations from contending with schema mutations unnecessarily.
