---
id: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
state: archived
type: operations
base_commit: 4ece8fd08dd7a76ccd327ba43df036b35c7d3778
---

# Enforce issue 119 release provenance on the exact selected tag commit with passing tests and a valid signature from the pinned trusted human signer before artifact publication, including manual backfills, deterministic contract tests, and recovery and key rotation documentation

## Intent

Enforce issue 119 release provenance on the exact selected tag commit with passing tests and a valid signature from the pinned trusted human signer before artifact publication, including manual backfills, deterministic contract tests, and recovery and key rotation documentation

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Tag-push and manual-backfill releases resolve and propagate one exact tag commit, publication fails when that commit lacks an attestation or passing-test evidence or a valid signature from the pinned human:leif key, publication succeeds for valid signed evidence, the tag binding is rechecked immediately before upload, ordinary pull-request Trust remains soft, deterministic contract tests cover missing note failed tests unsigned invalid signature untrusted signer and valid evidence, operator documentation covers note backup recovery compromise response and key rotation

## No-spec Rationale

Not applicable
