---
change: CHG-0042-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: tasks
---

# Tasks

- [x] Recover invalid key material when no encrypted envelope exists.
- [x] Add deterministic regression coverage for stale-key recovery.
- [x] Document store-lock serialization and REQ-aps-cli-020 evidence.
- [ ] Run strict fledge and SpecSync verification.
