# SecretStore stale-key recovery

## ADDED

### REQUIREMENT REQ-aps-cli-026

When no `secret.enc` envelope exists, a fresh SecretStore SET SHALL recover an
invalid stale `secret.key` before creating replacement key material. The fresh
SET operation SHALL remain serialized by `secret.store.lock`.

Acceptance Criteria
- A partial `secret.key` does not make the first fresh SET fail with
  `persistenceFailed`.
- A successful recovery leaves a valid key and decryptable envelope.