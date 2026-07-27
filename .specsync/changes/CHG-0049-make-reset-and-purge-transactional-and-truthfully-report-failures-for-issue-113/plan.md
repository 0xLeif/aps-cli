---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: plan
---

# Plan

1. Introduce throwing reset and purge APIs with injectable filesystem failure
   seams and stable domain-error mapping.
2. Add unlocked, postcondition-verified regular-leaf deletion for callers that
   already hold the appropriate storage lock.
3. Change SecretStore reset to a throwing envelope-only operation serialized by
   `secret.store.lock`, preserving `secret.key`.
4. Change FileState reset to encode first and atomically overwrite under the
   canonical per-file lock, including read-back verification.
5. Refactor schema removal plus purge into one schema-lock transaction with
   schema-first, storage-second lock ordering and original-schema rollback.
6. Add a stable rollback failure and an explicit fail-fast bulk reset report,
   then route human and machine CLI output through the shared error contract.
7. Record mutation statistics only after verified reset success.
8. Add deterministic unit, subprocess, smoke, concurrency, and tri-platform
   regression tests.
9. Update README, dynamic-schema documentation, CLI schema payloads, and
   canonical aps-cli and state-store specifications.
10. Run the verification lane, SpecSync verification, Trust, and GitHub checks.
