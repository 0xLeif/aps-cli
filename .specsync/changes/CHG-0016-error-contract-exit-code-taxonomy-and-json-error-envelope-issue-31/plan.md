---
change: CHG-0016-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31
artifact: plan
---

# Plan

1. Extend `APSError` with code/exitCode/hint.
2. Add `ErrorEnvelope`, `structuredErrorsEnabled`, `writeError`, and `fail`
   to `CLIOutput`; route every command through `fail`.
3. Split disk-reader failure modes; add `ensureReadable`; map `set`
   verification failures to `persistenceFailed`.
4. Tests: taxonomy mapping, envelope shape, ensureReadable semantics.
5. Smoke: exit codes 64/65/73, stdout purity, envelope greps,
   `APS_ERROR_JSON=1`.
6. Specs and README in the same change (spec lockstep rule).
