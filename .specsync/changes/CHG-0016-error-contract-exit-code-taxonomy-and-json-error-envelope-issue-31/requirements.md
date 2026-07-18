---
change: CHG-0016-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31
artifact: requirements
---

# Requirements

- REQ-aps-cli-002 extended: taxonomy exit codes (64/65/69/70/73),
  envelope shape with stable codes, stdout purity on error, corrupt state
  exits 65.
- New REQ-state-store-011: `ensureReadable` distinguishes missing from
  corrupt persisted state; readers throw `persistenceFailed` when missing,
  `decodingFailed` when corrupt.
