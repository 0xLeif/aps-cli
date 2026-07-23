---
change: CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: requirements
---

# Requirements

### REQ-aps-cli-020

The encrypted-file SecretStore SHALL serialize fresh `set` key recovery or
creation, sealing, atomic envelope persistence, and read-back verification
through `secret.store.lock`. If no `secret.enc` exists, an invalid stale
`secret.key` SHALL be removed before creating a replacement. Direct missing or
invalid key access SHALL use `secret.key.lock`, while valid existing-key reads
SHALL not require that lock.
Passphrase-mode writes SHALL ignore stale `secret.key` paths. Existing-envelope
SET SHALL preserve persistence failures from unreadable or missing envelopes
while translating invalid-key failures to `secretUnlockFailed`.

### REQ-aps-cli-026

When no `secret.enc` envelope exists, a fresh SecretStore SET SHALL recover an
invalid stale `secret.key` before creating replacement key material. The fresh
SET operation SHALL remain serialized by `secret.store.lock`. A corrupt key
with an existing `secret.enc` envelope SHALL surface `secretUnlockFailed`, and
recovery SHALL never remove a `secret.key` directory.
