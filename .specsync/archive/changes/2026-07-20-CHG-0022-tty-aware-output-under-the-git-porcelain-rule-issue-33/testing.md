---
change: CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-019 | `testTTYTableAlignsColumnsAndBoldsHeader`, `testStyleIsIdentityWhenColorDisabled`, `testEncodeJSONIsCompactOffTTY`, `testEncodeAutoIsCompactOffTTY`; smoke asserts TSV/no-ANSI keys, compact greps, watch --json alias, keys --quiet |

## Suites

- `swift test`
- `fledge lanes run verify`
