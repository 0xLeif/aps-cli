# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-001 | `testDemoKeyMetadata`, `Scripts/smoke.sh` (`keys` lists secret) |
| REQ-aps-cli-015 | `testSecretSecureStateRoundTrip`, `testSecretResetDeletesKeychainItem`, README Keychain section, Darwin smoke secret block |
| REQ-state-store-013 | `testSecretSecureStateRoundTrip`, `testSecretResetDeletesKeychainItem`, `testSecretPersistsAcrossStateStoreInstances` / `testSecretSetFailsWithoutKeychain` |

## Suites

- `swift test` (Darwin SecureState tests; Linux keychainUnavailable)
- `./Scripts/smoke.sh` (secret round-trip on Darwin only)
- `fledge lanes run verify`
