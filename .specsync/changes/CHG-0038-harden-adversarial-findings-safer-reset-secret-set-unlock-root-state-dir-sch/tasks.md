---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: tasks
---

# Tasks

- [x] SpecSync artifacts + deltas for aps-cli / state-store
- [x] Root `--state-dir` peel + boot precedence
- [x] Safer reset (`--all` seed-only, `--registered` full wipe)
- [x] SecretStore.set unlock-before-rewrite
- [x] SchemaFileLock around addKey/removeKey (+ materialize race)
- [x] README / Schema schemaVersion 4 / smoke.sh + smoke.ps1
- [x] Unit tests for unlock, peel, reset scope, parallel schema adds
- [x] `fledge lanes run verify` (or portable Scripts wrappers)
