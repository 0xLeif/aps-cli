---
change: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
artifact: design
---

# Design

Split absent recipient mode from raw-value decoding in `envelopeKind`. Extend
the final POSIX descriptor/path identity check with exact mode checks and fail
closed without another repair attempt. Expose the canonical root selected by a
`SecretStore`, capture it from the watch's initial snapshot store, and rebuild
later stores beneath that fixed path so descendant validation still repeats.
