---
id: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
state: archived
type: bug_fix
base_commit: 512c307a71c1d84e4ddf60eea34de3dc221ec903
---

# Make schema.json authoritative for built-in and dynamic key names for issue 112

## Intent

Make schema.json authoritative for built-in and dynamic key names for issue 112

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- All CLI string-key operations dispatch through the resolved schema entry even when its name matches a DemoKey seed; forced overrides of type, storage, path, initial value, object shape, slice metadata, and output typing are honored by get, set, reset, watch, dump, and seed bulk reset; schema projection and runtime output agree; default seeded behavior remains compatible; StoredState compatibility is explicitly tested and documented; shell and PowerShell smoke plus unit tests cover overridden built-in names.

## No-spec Rationale

Not applicable
