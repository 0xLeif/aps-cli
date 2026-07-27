---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: docs
---

# Docs

Update README reset and registry examples to state that reset and purge report
detected persistence failures and never print a success line after failure.
Document partial bulk reset output with `reset`, `failed`, and `notAttempted`
keys.

Update `docs/design/dynamic-schema.md` with:

- schema-lock then storage-lock ordering;
- schema candidate write, purge, and original-schema rollback;
- FileState atomic reset replacement;
- SecretStore envelope-only reset and preservation of `secret.key`;
- mutation statistics only after verified success;
- the detected-error transaction boundary and explicit exclusion of crash and
  power-loss atomicity.

Update `aps schema` payload and error tables for the bulk result shape and
stable rollback error. Examples must keep stdout empty on failure and show the
machine error on stderr.
