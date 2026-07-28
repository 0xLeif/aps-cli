---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: context
---

# Context

Late review of PR #128 found gaps after CHG-0050 had already been accepted and
applied. Its immutable definition cannot be rewritten. This successor change
records the review-driven behavior and canonical contract corrections while
keeping all implementation in the existing PR.

The gaps affect cross-process key repair locking, POSIX state-root handling,
permission-repair error mapping, key-file watch revalidation, and redundant
passphrase KDF work in CLI output.
