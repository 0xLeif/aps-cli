---
change: CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on
artifact: context
---

# Context

Issue #31 (design decision 4). Originally built as CHG-0016/PR #47, then
rebuilt on fresh main after CHG-0016 (multi-writer corruptState, PR #43)
landed the corrupt-state slice with different naming. This change keeps the
merged `corruptState` semantics and adds the full error contract on top.

## Decisions

- sysexits-aligned taxonomy for every APSError: 64 usage, 65 data
  (`corruptState` + `decodingFailed`), 69 unavailable, 70 internal,
  73 write did not persist (66 reserved).
- One failure path (`CLIOutput.fail`): human line on stderr, optional
  `{"error":{"code","message","hint"}}` envelope, taxonomy exit code.
  Replaces the corruptState-only `reportAPSError` shim and the old
  flatten-to-`ValidationError` bridge.
- Envelope timing: machine modes (`--json`/`--jsonl`) or `APS_ERROR_JSON=1`.
- Loud corrupt-state stays with CHG-0016's `requireDecodableDiskState`;
  this change adds no duplicate mechanism.
