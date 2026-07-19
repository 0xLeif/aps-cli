---
id: CHG-0023-watch-signal-handling-and-termination-semantics-issue-34
state: accepted
type: feature
base_commit: c4ecd60b2a46bca4780f1b4af79a1d495d646287
---

# Watch signal handling and termination semantics (issue 34)

## Intent

watch signal handling and termination semantics (issue 34)

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- watch stops cleanly for count (exit 0), timeout (exit 124), SIGINT (exit 130), and SIGTERM (exit 143); the stop reason appears as a terminal {type:end,reason:...} event in --jsonl mode or a stderr line in human mode; the jsonl stream never contains non-JSON lines; an unbounded watch prints a one-time stderr hint; smoke covers all exit paths including kill -INT; specs updated.

## No-spec Rationale

Not applicable
