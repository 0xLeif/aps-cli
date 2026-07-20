---
change: CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-002 | `testAPSErrorContractCodesAndExitCodes`, `testErrorEnvelopeEncodesStableShape`, `testStructuredErrorsEnabledModes`; smoke asserts exit 64/65/73, stdout purity, and envelope greps incl. `APS_ERROR_JSON=1` |

## Suites

- `swift test`
- `fledge lanes run verify`
