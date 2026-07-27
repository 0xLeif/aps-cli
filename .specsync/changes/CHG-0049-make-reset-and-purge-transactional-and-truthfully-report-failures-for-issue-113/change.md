---
id: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
state: draft
type: bug_fix
base_commit: b0647eade46eeac974533e84f93440db956031db
---

# Make reset and purge transactional and truthfully report failures for issue 113

## Intent

Make reset and purge transactional and truthfully report failures for issue 113

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Detected reset and purge persistence failures produce stable nonzero errors and no false success; secret envelope deletion is locked and postcondition-verified while preserving shared key material; schema removal with purge holds the schema lock and restores the original schema on detected purge failure; bulk reset reports reset, failed, and not-attempted keys with stats only for successes; deterministic tests cover wrong-kind and unwritable paths, injected deletion and rollback failures, concurrent path reuse, secret reset races, and macOS Linux Windows behavior.

## No-spec Rationale

Not applicable
