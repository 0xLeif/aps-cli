---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: tasks
---

# Tasks

- [x] Replace the split key repair lock with `secret.store.lock`.
- [x] Canonicalize POSIX roots and preserve safe parent modes.
- [x] Reject writable roots without changing key or directory contents.
- [x] Map permission-repair failures to the stable security error.
- [x] Reload key-file recipients for changed watch snapshots.
- [x] Remove duplicate CLI encrypted reads and return the resolved set entry.
- [x] Correct canonical requirements and testing documentation.
- [x] Add focused regressions and pass all 234 tests plus the full verify lane.
