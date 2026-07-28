---
change: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
artifact: context
---

# Context

Final review of PR 128 found three narrow gaps after the earlier security
hardening: absent version 2 recipient modes used the unsupported error,
POSIX permission widening after the initial repair could escape final
validation, and a registered encrypted watch could follow a retargeted
state-root symlink.
