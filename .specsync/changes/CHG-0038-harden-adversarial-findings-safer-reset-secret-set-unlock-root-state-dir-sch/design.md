---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: design
---

# Design

**Root `--state-dir`:** custom `@main` peels `--state-dir PATH` / `--state-dir=PATH`
before the first subcommand token, stores an override on `APSPaths`, and forwards the
remaining argv to `Aps.main`. `boot(stateDir:)` prefers an explicit subcommand option
over the peeled root override over `APS_HOME`.

**Safer reset:** `--all` calls `StateStore.resetAll()` (DemoKey seed only). New
`--registered` calls `resetAllRegistered()`. Mutual exclusion with a key argument.

**Secret SET unlock:** when `hasSecret`, `set` calls `get()` first; unlock failure
throws `secretUnlockFailed` and leaves ciphertext untouched. First write / post-reset
still seals with the current recipient key (key file or passphrase). Documents that
passphrase gating is stateful until a keyed envelope exists.

**Schema lock:** `SchemaFileLock` combines a process-local non-recursive mutex
(same-process threads; plain `flock` does not serialize those on Linux) with
POSIX `fcntl(F_SETLKW)` (EINTR-retried; Darwin/Glibc flock fields set by name)
for cross-process exclusion. Windows uses exclusive create/retry on
`schema.json.lock.held` with a PID+timestamp payload; a held file is stale when
the PID is dead or the timestamp is older than five minutes. `addKey` /
`removeKey` re-load under the lock before write. Materialize double-checks under
the same lock to avoid racing a peer add. Callers must not nest
`withExclusiveLock` (use UserSchema `*Unlocked` helpers inside the body).
