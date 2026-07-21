---
id: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
state: implementing
type: bug_fix
base_commit: 2eac0ec7e7bf7bbd69976c30d9d553f19aacacc1
---

# Harden adversarial findings: safer reset, secret SET unlock, root state-dir, schema lock

## Intent

Harden adversarial findings: safer reset, secret SET unlock, root state-dir, schema lock

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Root --state-dir works before subcommand; reset --all is seed-only with --registered for full wipe; SecretStore.set unlocks existing envelope before rewrite; schema add/remove holds exclusive lock and re-reads; tests+smoke cover these; README updated.

## No-spec Rationale

Not applicable
