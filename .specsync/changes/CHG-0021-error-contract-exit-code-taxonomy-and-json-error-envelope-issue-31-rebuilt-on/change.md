---
id: CHG-0021-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31-rebuilt-on
state: accepted
type: feature
base_commit: 8cf886df7ac87eac4234fc3fb8c13f46362e08d6
---

# Error contract: exit-code taxonomy and JSON error envelope (issue 31, rebuilt on corruptState main)

## Intent

Error contract: exit-code taxonomy and JSON error envelope (issue 31, rebuilt on corruptState main)

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Domain errors exit per the taxonomy (64 usage, 65 corrupt/undecodable state, 69 unavailable, 70 internal, 73 persist-fail) through one CLIOutput.fail path; stderr carries a human line plus a {error:{code,message,hint}} envelope with --json/--jsonl or APS_ERROR_JSON=1; stdout stays empty on error; codes include corrupt_state from the merged multi-writer work; tests and smoke assert all of it.

## No-spec Rationale

Not applicable
