---
id: CHG-0016-error-contract-exit-code-taxonomy-and-json-error-envelope-issue-31
state: accepted
type: feature
base_commit: c0c5b4bfb7c712506f9795c80889f03094596629
---

# Error contract: exit-code taxonomy and JSON error envelope (issue 31)

## Intent

Error contract: exit-code taxonomy and JSON error envelope (issue 31)

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Exit codes follow the taxonomy (64 usage, 65 corrupt state, 69 unavailable, 70 internal, 73 persist-fail); domain errors emit a human stderr line plus a {error:{code,message,hint}} envelope with --json/--jsonl or APS_ERROR_JSON=1; corrupt note.json/profile.json exits 65 instead of returning the initial value; stdout stays empty on error; tests and smoke assert all of it.

## No-spec Rationale

Not applicable
