---
change: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
artifact: research
---

# Research

The strict envelope contract distinguishes malformed absent fields from
declared but unsupported values. POSIX final `fstat` and `fstatat` snapshots
provide the last observable pre-return permission check. Reusing the configured
symlink path would re-canonicalize a new target, while reusing one store would
skip descendant validation; pinning the first canonical root and rebuilding
stores satisfies both constraints.
