---
change: CHG-0016-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31
artifact: design
---

# Design

- `APSError` gains `code` (stable snake_case), `exitCode` (Int32 taxonomy),
  and `hint` (actionable next step).
- `CLIOutput.ErrorEnvelope` (`{"error":{"code","message","hint"}}`) encodes
  via `encodeLine` with `.withoutEscapingSlashes`.
- `CLIOutput.fail(_:json:)` writes the human line, conditionally the
  envelope, then throws `ExitCode(error.exitCode)`. All commands catch
  `APSError` through it; ArgumentParser usage errors keep their own 64.
- `readNoteFromDisk` / `readProfileFromDisk` split failure modes:
  missing/unreadable -> `persistenceFailed`; existing-but-undecodable ->
  `decodingFailed`. `set` write verification maps any read-back failure to
  `persistenceFailed`.
- `ensureReadable(_:)` runs before `get` / `watch` output for disk-backed
  keys; missing file passes, corrupt file throws `decodingFailed`.
