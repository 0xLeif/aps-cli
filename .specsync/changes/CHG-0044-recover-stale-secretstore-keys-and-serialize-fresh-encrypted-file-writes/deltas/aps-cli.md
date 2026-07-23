# SecretStore stale-key recovery

## MODIFIED

### REQUIREMENT REQ-aps-cli-020

The encrypted-file SecretStore SHALL serialize fresh `set` key recovery or
creation, sealing, atomic envelope persistence, and read-back verification
through `secret.store.lock`. If no `secret.enc` exists, an invalid stale
`secret.key` SHALL be removed before creating a replacement. Direct missing or
invalid key access SHALL use `secret.key.lock`, while valid existing-key reads
SHALL not require that lock. Passphrase-mode writes SHALL ignore stale
`secret.key` paths. Existing-envelope SET SHALL preserve persistence failures
from unreadable or missing envelopes while translating invalid-key failures to
`secretUnlockFailed`.

Acceptance Criteria
- Fresh and parallel SecretStore SET operations remain serialized and leave a decryptable envelope.
- Invalid stale key material is recovered only when no envelope exists.
- Existing-envelope persistence failures remain `persistenceFailed`; invalid keys surface `secretUnlockFailed`.
