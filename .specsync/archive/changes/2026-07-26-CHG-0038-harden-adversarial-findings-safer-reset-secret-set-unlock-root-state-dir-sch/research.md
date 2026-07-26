---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: research
---

# Research

Adversarial dogfood evidence (issues `#85`, `#87`, `#88`, `#89`, `#90`):

- Atomic `Data.write(.atomic)` kept `schema.json` valid JSON but did not prevent lost updates.
- SIGKILL mid-set did not tear FileState; injected garbage correctly exits 65.
- Secret GET already threw `secretUnlockFailed` on wrong passphrase; SET did not.
- ArgumentParser only binds `--state-dir` on subcommands via `StateOptions`, so root
  placement fails with "Unknown option".

Alternatives rejected: docs-only for `#87` (help already implies global); explicit
`aps secret rekey` (larger surface; unlock-before-set covers the security hole);
CAS-only schema writes without a lock (harder on Windows, still racy without retry).
