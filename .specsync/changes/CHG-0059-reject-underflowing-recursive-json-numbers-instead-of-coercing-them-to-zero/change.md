---
id: CHG-0059-reject-underflowing-recursive-json-numbers-instead-of-coercing-them-to-zero
state: accepted
type: bug_fix
base_commit: 01128bd8881938668233b830ce326f3f789fa035
---

# Reject underflowing recursive JSON numbers instead of coercing them to zero

## Intent

Reject underflowing recursive JSON numbers instead of coercing them to zero

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Recursive JSON values containing 1e-400 or -1e-400 fail decoding instead of becoming integer zero; ordinary zero and supported numeric values still decode; focused regressions and the full quality lane pass.

## No-spec Rationale

This enforces the existing recursive JSON value-preservation contract without changing public API or documented behavior.
