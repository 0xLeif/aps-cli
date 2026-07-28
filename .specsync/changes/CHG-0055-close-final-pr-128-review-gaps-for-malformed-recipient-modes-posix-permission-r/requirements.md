---
change: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
artifact: requirements
---

# Requirements

1. A missing or null version 2 `recipientMode` shall fail as
   `APSError.decodingFailed` before KDF work. An unrecognized non-null mode
   shall remain `APSError.unsupportedSecretEnvelope`.
2. POSIX key-file load and create shall require exact `0600` mode in final
   descriptor and path snapshots before accepting key material.
3. Registered encrypted watch shall pin the canonical state-root target chosen
   by its initial store for the watch lifetime.
4. Descendant validation shall continue beneath the pinned root on every
   encrypted watch poll.
