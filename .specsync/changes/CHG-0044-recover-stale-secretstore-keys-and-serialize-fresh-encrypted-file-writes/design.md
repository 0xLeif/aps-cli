---
change: CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: design
---

# Design

`SecretStore.set` already holds `secret.store.lock`, whose process-local mutex
is non-recursive. Fresh key recovery and creation therefore remain inside that
store lock rather than attempting to nest `secret.key.lock`. Reads of an
existing valid key stay lock-free; direct missing or invalid-key creation keeps
the dedicated key lock for first-use serialization.