---
id: CHG-0061-accept-finite-recursive-json-doubles-beyond-decimal-exponent-range
state: accepted
type: bug_fix
base_commit: 28a9781e057e5c019a7ff1fe08931246761e968e
---

# Accept finite recursive JSON doubles beyond Decimal exponent range

## Intent

Accept finite recursive JSON doubles beyond Decimal exponent range

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Finite Double values such as 1e-200 and 5e-324 decode successfully; underflowing 1e-400 remains rejected; Decimal-range precision checks remain enforced; focused regressions and the full quality lane pass.

## No-spec Rationale

This restores finite Double support promised by the existing recursive JSON contract without changing public API or canonical requirements.
