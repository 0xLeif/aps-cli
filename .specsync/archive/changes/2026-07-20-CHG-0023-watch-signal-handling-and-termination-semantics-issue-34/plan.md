---
change: CHG-0023-watch-signal-handling-and-termination-semantics-issue-34
artifact: plan
---

# Plan

1. Add WatchTermination.swift (SignalBox, handlers, StopReason).
2. Add CLIOutput.WatchEndEvent and writeError; rework Watch.run (reason
   tracking, terminal marker, exit codes, hint, jsonl purity).
3. Tests: StopReason tokens/exit codes, WatchEndEvent shape.
4. Smoke: count exit 0, timeout exit 124 with end event, SIGINT exit 130
   via kill -INT, jsonl purity check.
5. aps-cli spec (files list, termination invariant), REQ-aps-cli-012,
   README.
