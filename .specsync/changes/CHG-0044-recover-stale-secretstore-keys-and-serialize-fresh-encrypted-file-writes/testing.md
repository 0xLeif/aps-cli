---
change: CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-020 | `testSecretStoreParallelFreshWritesShareKeyFile`; `testSecretStoreFreshSetRecoversInvalidKeyWithoutEnvelope`; `Sources/aps/SecretStore.swift` store-lock path and stale-key recovery |
| REQ-aps-cli-026 | `testSecretStoreFreshSetRecoversInvalidKeyWithoutEnvelope`; `testSecretStoreExistingEnvelopeWithInvalidKeyThrowsUnlockFailed`; `testSecretStoreFreshSetDoesNotRemoveSecretKeyDirectory`; invalid-key recovery before `createFile` |

The fledge verification gate covers build, unit tests, smoke, and plugin validation.
