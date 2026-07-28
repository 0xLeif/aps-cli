---
change: CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext
artifact: testing
---

# Testing

| Requirement | Evidence |
|---|---|
| REQ-aps-cli-035 | `DynamicObjectTypingTests.testOutOfRangeIntegralJSONIsRejectedInsteadOfRounded` |
| REQ-state-store-028 | `APSTests.testEncryptedDiskPreflightRejectsSchemaIncompatiblePlaintext` |

The full serial and parallel suites, smoke, CI dogfood, action contract, and
plugin validation must also pass.
