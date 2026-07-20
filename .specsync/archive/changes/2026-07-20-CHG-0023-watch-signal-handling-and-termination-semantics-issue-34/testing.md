---
change: CHG-0023-watch-signal-handling-and-termination-semantics-issue-34
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-012 | `testStopReasonTokensAndExitCodes`, `testWatchEndEventEncodesTerminalMarker`; smoke covers count exit 0, timeout exit 124 with end event, SIGINT exit 130 via kill -INT, and jsonl purity |

## Suites

- `swift test`
- `fledge lanes run verify`
