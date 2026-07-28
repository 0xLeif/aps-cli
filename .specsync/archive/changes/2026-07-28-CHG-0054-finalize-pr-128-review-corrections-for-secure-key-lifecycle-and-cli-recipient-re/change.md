---
id: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
state: archived
type: bug_fix
base_commit: f722964daaaeccd9c717ca8f490679a3cd9184dc
---

# Finalize PR 128 review corrections for secure key lifecycle and CLI recipient reuse

## Intent

Finalize PR 128 review corrections for secure key lifecycle and CLI recipient reuse

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- All repair-capable key loads share secret.store.lock; symlinked POSIX roots round-trip without mode mutation; writable roots fail closed; permission-repair failures map to insecure_secret_key_file; changed key-file watch snapshots reload and revalidate the key; CLI get performs one encrypted read and encrypted set performs no post-commit decrypt; StateStore set returns the exact resolved entry; corrected canonical contracts and 234 tests pass the full verify lane

## No-spec Rationale

Not applicable
