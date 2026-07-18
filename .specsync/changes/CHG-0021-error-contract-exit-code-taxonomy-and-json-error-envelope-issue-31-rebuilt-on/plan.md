---
change: CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on
artifact: plan
---

# Plan

1. Extend `APSError` with code/exitCode/hint (corruptState included).
2. Add `ErrorEnvelope` + `fail` to `CLIOutput`; route get/set/watch through
   it (replacing `reportAPSError`) and add coverage to dump/reset.
3. Tests: taxonomy mapping, envelope shape, envelope modes,
   requireDecodableDiskState corrupt case.
4. Smoke: exit codes 64/65/73, stdout purity, envelope greps,
   `APS_ERROR_JSON=1`.
5. aps-cli spec + requirements + README in the same change (lockstep rule).
