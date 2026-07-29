---
id: CHG-0060-reject-fractional-recursive-json-values-when-double-encoding-would-change-their
state: accepted
type: bug_fix
base_commit: fd2b2ef5d5b95ff0b61895f7e1de8ee0996fa221
---

# Reject fractional recursive JSON values when Double encoding would change their decimal value

## Intent

Reject fractional recursive JSON values when Double encoding would change their decimal value

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- A fractional JSON value such as 1.0000000000000000001 fails decoding instead of becoming 1.0; supported finite numbers retain their decimal value after Double encoding; focused regressions and the full quality lane pass.

## No-spec Rationale

This enforces the existing recursive JSON exact-value contract without changing the public API or canonical requirement.
