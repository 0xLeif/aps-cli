---
change: CHG-0023-watch-signal-handling-and-termination-semantics-issue-34
artifact: design
---

# Design

- New `Sources/aps/WatchTermination.swift`: `SignalBox` (lock-guarded
  signal record), `installWatchSignalHandlers` (SIG_IGN plus
  DispatchSourceSignal on the main queue, delivered by the watch loop's
  RunLoop draining), and `StopReason` (token / exitCode / summary).
- Watch.run composes `shouldContinue` from count, deadline, and the signal
  box, recording the first stop reason. After the loop: terminal
  `WatchEndEvent` on stdout in `--jsonl` mode or a stderr line, then
  `ExitCode(reason.exitCode)` when non-zero.
- jsonl purity: the encode-failure fallback now writes a WatchErrorEvent
  with `error: "encoding_failed"`.
