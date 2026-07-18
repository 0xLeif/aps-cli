---
change: CHG-0025-aps-schema-self-describing-contract-endpoint-issue-32
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-016 | `testSchemaDocumentCoversAllKeysAndCommands`, `testSchemaErrorTableIsStable`, `testSchemaDocumentEncodesValidContractJSON`; smoke greps `schemaVersion`, key entries, `corrupt_state`, and asserts `cliVersion` equals `aps --version` |

## Suites

- `swift test`
- `fledge lanes run verify`
