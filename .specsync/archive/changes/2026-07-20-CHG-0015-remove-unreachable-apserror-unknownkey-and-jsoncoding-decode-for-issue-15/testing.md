---
change: CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-005 | `testAPSErrorDescriptionsAreActionable` (no unknownKey); SecureState keychainUnavailable coverage elsewhere |
| REQ-state-store-002 | `testDumpIncludesKeysAndUsesDependency` / dump via `encodePretty` |

## Suites

- `swift test`
- `fledge lanes run verify`
