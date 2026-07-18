---
change: CHG-0016-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-002 | `testAPSErrorContractCodesAndExitCodes`, `testErrorEnvelopeEncodesStableShape`, `testStructuredErrorsEnabledModes`; smoke asserts exit 64/65/73, stdout purity, and both envelope greps |
| REQ-state-store-011 | `testEnsureReadableMissingFileIsInitialSemantics`, `testEnsureReadableCorruptFileThrowsDecodingFailed`, `testEnsureReadableCorruptProfileThrowsDecodingFailed` |

## Suites

- `swift test`
- `fledge lanes run verify`
