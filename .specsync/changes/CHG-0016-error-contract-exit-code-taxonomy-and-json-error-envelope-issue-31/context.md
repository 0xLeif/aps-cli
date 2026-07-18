---
change: CHG-0016-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31
artifact: context
---

# Context

Issue #31 (design decision 4): every domain error collapsed into
`ValidationError` and exit 64 with human-only text, so agents could not
distinguish "fix your invocation" from "environment broken". Corrupt
persisted state was silently masked as the initial value.

## Decisions

- sysexits-aligned taxonomy: 64 usage, 65 corrupt data, 69 unavailable,
  70 internal, 73 write did not persist (66 reserved).
- One failure path (`CLIOutput.fail`): human line on stderr, optional
  `{"error":{"code","message","hint"}}` envelope, taxonomy exit code.
- Envelope timing: machine modes (`--json`/`--jsonl`) or `APS_ERROR_JSON=1`.
- Loud corrupt-state: `StateStore.ensureReadable` distinguishes missing
  (initial value) from existing-but-undecodable (exit 65) before
  `get` / `watch` output.
