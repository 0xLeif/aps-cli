---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: tasks
---

# Tasks

- [ ] Add deterministic filesystem failure injection for reset, purge, and
  schema rollback tests.
- [ ] Implement throwing verified regular-leaf deletion for locked callers.
- [ ] Implement locked SecretStore envelope-only reset that preserves shared
  key material.
- [ ] Implement atomic locked FileState reset and verified Slice reset.
- [ ] Make schema removal plus purge one ordered-lock transaction with rollback.
- [ ] Add stable rollback failure and explicit fail-fast bulk reset reporting.
- [ ] Record stats only for verified successful resets.
- [ ] Update CLI human, JSON, schema, and error output contracts.
- [ ] Add adversarial, concurrency, subprocess, and smoke tests.
- [ ] Update README, dynamic-schema documentation, and canonical specs.
- [ ] Pass verification, SpecSync, Trust, and tri-platform GitHub checks.
