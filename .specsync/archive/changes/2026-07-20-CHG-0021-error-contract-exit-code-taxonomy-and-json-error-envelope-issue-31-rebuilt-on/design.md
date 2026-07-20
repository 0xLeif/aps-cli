---
change: CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on
artifact: design
---

# Design

- `APSError` gains `code` (stable snake_case), `exitCode` (Int32 taxonomy,
  reusing `corruptStateExitCode` for the two data cases), and `hint`.
- `CLIOutput.ErrorEnvelope` encodes via `encodeLine` with
  `.withoutEscapingSlashes`.
- `CLIOutput.fail(_:json:)` writes the human line, conditionally the
  envelope, then throws `ExitCode(error.exitCode)`. All commands catch
  `APSError` through it, including dump and reset which previously
  propagated raw errors.
- The watch jsonl corrupt-state event from CHG-0016 is unchanged; the
  process exit after it now follows the same taxonomy via `fail`.
