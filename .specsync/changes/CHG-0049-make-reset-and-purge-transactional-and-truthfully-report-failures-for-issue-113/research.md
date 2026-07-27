---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: research
---

# Research

The reset and purge audit found four related failure modes:

- `SecretStore.reset` is nonthrowing and discards both safe-path validation and
  removal failures.
- FileState reset removes a file and then calls the normal set path. A failed
  replacement loses the pre-reset value.
- schema removal commits under `schema.json.lock`, then purges after releasing
  the lock. This permits path reuse and leaves an unregistered data file when
  purge fails.
- bulk reset records no explicit partial-progress result, so callers cannot
  distinguish successful, failed, and unattempted keys.

`SchemaStoragePath.removeRegularFileIfPresent` already supplies the correct
leaf-only deletion primitive. `SchemaFileLock.withExclusiveLock` can be reused
for both schema and storage locks, but its process mutex is non-recursive. The
implementation must therefore avoid reacquiring a lock already held and expose
unlocked adapter helpers for transaction bodies.

`SecretStore.set` already serializes envelope writes with
`secret.store.lock`. Reset must use that same lock to prevent a set/reset race.
The state-root `secret.key` is recipient material, not the encrypted entry
itself. Deleting it during reset can make other envelopes unreadable and is not
part of the reset postcondition.

Foundation atomic file writes provide replacement behavior suitable for
FileState reset, but they do not make a multi-file schema and data operation
crash atomic. Retaining the original schema and restoring it after a detected
purge failure gives a truthful API boundary without overstating durability.

Portable permission tests alone are insufficient, especially under privileged
CI users and on Windows. Deterministic injected filesystem failures are needed
alongside real wrong-kind, directory, symbolic-link, and read-only cases.
