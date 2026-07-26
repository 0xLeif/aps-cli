# SecretStore stale-key recovery

## MODIFIED

### REQUIREMENT REQ-aps-cli-020

The `secret` key SHALL be backed by an encrypted-file secret store under the
state root (ephemeral X25519 + HKDF + ChaCha20-Poly1305 via swift-crypto), with
zero interactive prompts in key-file mode and passphrase mode via
`APS_SECRET_PASSPHRASE`. When `secret.enc` already exists, `set` SHALL unlock
with the current recipient key before rewriting; unlock failure SHALL leave the
file unchanged and surface `APSError.secretUnlockFailed`. Passphrase vs key-file
mode remains stateful: a fresh or reset store seals with whichever recipient is
active on first write.

The encrypted-file SecretStore SHALL serialize fresh `set` key recovery or
creation, sealing, atomic envelope persistence, and read-back verification
through `secret.store.lock`. If no `secret.enc` exists, an invalid stale
`secret.key` SHALL be removed before creating a replacement. Direct missing or
invalid key access SHALL use `secret.key.lock`, while valid existing-key reads
SHALL not require that lock. Passphrase-mode writes SHALL ignore stale
`secret.key` paths. Existing-envelope SET SHALL preserve persistence failures
from unreadable or missing envelopes while translating invalid-key failures to
`secretUnlockFailed`. Fresh key-creation disk failures SHALL remain
`persistenceFailed`. When an envelope exists, unlock paths SHALL NOT create or
truncate `secret.key`.

Acceptance Criteria
- `secret` round-trips set/get/reset with ciphertext at rest in `secret.enc`; the key file is mode 0600.
- No Security.framework/Keychain imports; works on macOS and Linux.
- Wrong passphrase on `get` fails with `APSError.secretUnlockFailed`; corrupt envelope fails with `APSError.decodingFailed`.
- Wrong passphrase on `set` against an existing envelope fails with `secretUnlockFailed` and does not change ciphertext.
- Passphrase entry is env-var based; an optional TTY getpass prompt exists when `APS_SECRET_USE_PASSPHRASE=1`.
- Fresh and parallel SecretStore SET operations remain serialized and leave a decryptable envelope.
- Invalid stale key material is recovered only when no envelope exists (including after empty TTY passphrase fallback).
- Existing-envelope persistence failures remain `persistenceFailed`; invalid keys surface `secretUnlockFailed`.
- Fresh key-creation write failures remain `persistenceFailed`; unlock never truncates an existing key path.

### REQUIREMENT REQ-aps-cli-026

When no `secret.enc` envelope exists, a fresh SecretStore SET SHALL recover an
invalid stale `secret.key` before creating replacement key material. The fresh
SET operation SHALL remain serialized by `secret.store.lock`.

Acceptance Criteria
- A partial `secret.key` does not make the first fresh SET fail with
  `persistenceFailed`.
- A successful recovery leaves a valid key and decryptable envelope.
- A `secret.key` directory is never removed during recovery, and a corrupt
  existing key with an envelope surfaces `secretUnlockFailed`.
