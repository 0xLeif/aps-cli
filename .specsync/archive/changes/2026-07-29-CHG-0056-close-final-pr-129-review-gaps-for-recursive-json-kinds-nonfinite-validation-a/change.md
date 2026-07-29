---
id: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
state: archived
type: bug_fix
base_commit: 65b8b5c01859dcec3610fc5b747a48f9fdca378e
---

# Close final PR 129 review gaps for recursive JSON kinds, nonfinite validation, and corrupt StoredState reads

## Intent

Close final PR 129 review gaps for recursive JSON kinds, nonfinite validation, and corrupt StoredState reads

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- SchemaJSON preserves supported numeric behavior without corrupting declared Int fields; schema validation rejects nonfinite doubles at every recursive depth; schema version 6 advertises null, finite number, array, object, string, integer, and boolean payload values; present but undecodable StoredState values fail as corrupt_state while absent values still use initials; focused regressions and the full 252-test quality lane plus hosted CI pass.

## No-spec Rationale

Not applicable
