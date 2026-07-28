---
change: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
artifact: plan
---

# Plan

1. Correct error classification without changing the version 2 wire format.
2. Fail closed when final POSIX mode snapshots are not exact `0600`.
3. Pin the initial canonical watch root while rebuilding stores per poll.
4. Verify focused regressions, full local lanes, and hosted platform gates.
