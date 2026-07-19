---
id: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
state: accepted
type: feature
base_commit: c4ecd60b2a46bca4780f1b4af79a1d495d646287
---

# Encrypted-file secret store via swift-crypto (issue 35)

## Intent

Encrypted-file secret store via swift-crypto (issue 35)

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- secret round-trips set/get/reset through an encrypted-file store under the state root (ephemeral X25519 + HKDF + ChaCha20-Poly1305 via swift-crypto, ciphertext at rest, key file mode 0600); zero interactive prompts in key-file mode; passphrase mode via APS_SECRET_PASSPHRASE with loud secretUnlockFailed on wrong key; corrupt envelope fails decodingFailed; no Security.framework imports remain; keychainUnavailable case removed; cross-process watch reads the store directly; tests and smoke cover all of it on macOS and Linux.

## No-spec Rationale

Not applicable
