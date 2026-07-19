---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-005 | `testAPSErrorDescriptionsAreActionable` plus `testSecretPassphraseRoundTripAndWrongKey` covering `secretUnlockFailed` |
| REQ-aps-cli-020 | `testSecretEncryptedStoreRoundTrip`, `testSecretResetDeletesStoreFile`, `testSecretKeyFilePermissionsAre0600`, `testSecretStoreCorruptEnvelopeThrowsDecodingFailed`, `testSecretPersistsAcrossStateStoreInstances`, `testSecretPassphraseRoundTripAndWrongKey`; smoke: key-file round-trip, 0600 perms, reset, passphrase right/wrong |

## Suites

- `swift test`
- `fledge lanes run verify`
