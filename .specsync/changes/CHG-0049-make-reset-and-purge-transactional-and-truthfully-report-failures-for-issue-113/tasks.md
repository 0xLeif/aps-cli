---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: tasks
---

# Tasks

- [x] Add deterministic filesystem failure injection for reset, purge, and
  schema rollback tests.
- [x] Implement throwing verified regular-leaf deletion for locked callers.
- [x] Implement locked SecretStore envelope-only reset that preserves shared
  key material.
- [x] Implement atomic locked FileState reset and verified Slice reset.
- [x] Make schema removal plus purge one ordered-lock transaction with rollback.
- [x] Add stable rollback failure and explicit fail-fast bulk reset reporting.
- [x] Record stats only for verified successful resets.
- [x] Update CLI human, JSON, schema, and error output contracts.
- [x] Add adversarial, concurrency, subprocess, and smoke tests.
- [x] Update README, dynamic-schema documentation, and canonical specs.
- [x] Pass the local seven-step fledge verification lane.

SpecSync acceptance and Trust run after implementation verification. The pull
request must pass macOS, Linux, Linux smoke, Windows, and Trust checks before
merge.
