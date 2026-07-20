---
change: CHG-0023-watch-signal-handling-and-termination-semantics-issue-34
artifact: context
---

# Context

Issue #34 (design round 2, decision: both channels). watch ran forever
with no signal handling, bounded exits always returned 0 whether count or
timeout stopped the loop, and the jsonl fallback could inject a raw
non-JSON line into the stream.

## Decisions

- Exit codes: 0 count (request satisfied), 124 timeout (GNU convention),
  128+signal (130 SIGINT, 143 SIGTERM).
- Reason is observable in both channels: terminal
  `{"type":"end","reason":...}` event in `--jsonl` mode, stderr summary in
  human mode.
- The jsonl stream never contains non-JSON lines: event-encode failures
  now emit a WatchErrorEvent instead of the raw value line.
- Unbounded watch prints a one-time stderr hint suggesting
  `--count` / `--timeout`.
