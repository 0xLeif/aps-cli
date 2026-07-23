---
change: CHG-0042-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: research
---

# Research

`SchemaFileLock` uses a non-recursive process mutex, so taking
`secret.key.lock` from inside the existing `secret.store.lock` body would
deadlock same-process callers. The store lock is the safe serialization boundary
for fresh `set`; the dedicated key lock remains for direct key materialization.
