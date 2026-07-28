---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: docs
---

# Docs

Update `specs/aps-cli/requirements.md` and `specs/aps-cli/testing.md` to record:

- one shared repair-capable key lock;
- POSIX root canonicalization, safe-mode preservation, and writable-root
  rejection;
- changed-snapshot key-file revalidation;
- stable permission-repair security errors; and
- single-read CLI get plus no redundant encrypted set output decrypt.

The immutable CHG-0050 workspace remains unchanged. Its three late wording
corrections are superseded by the canonical contract and this successor change:
the actual KDF wire keys are `algorithm`, `rounds`, `blockSize`,
`parallelism`, and `outputByteCount`; unsupported envelopes are distinct from
malformed envelopes; invalid existing key material is never replaced.
