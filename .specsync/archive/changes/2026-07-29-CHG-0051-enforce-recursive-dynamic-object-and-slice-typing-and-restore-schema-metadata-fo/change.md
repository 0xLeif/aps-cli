---
id: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
state: archived
type: bug_fix
base_commit: ebedc5994e59454ef688f7206236207a9f6f9ac3
---

# Enforce recursive dynamic object and Slice typing and restore schema metadata for issue 114

## Intent

Enforce recursive dynamic object and Slice typing and restore schema metadata for issue 114

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Machine get, set, dump, watch, and reset emit every registered object as structural JSON without field loss; one recursive JSON value represents supported nested objects and primitives; schema validation rejects initial/type/object-shape mismatches and rejects Slice definitions whose FileState object parent, declared field, field type, or typed initial is invalid; key add exposes usable repeatable object-field declarations; runtime writes and reads enforce declared object and Slice types before mutation or output; aps schema publishes userSchema.keyCount equal to keys.count and bumps schemaVersion to 6; Unix and Windows smoke, unit tests, strict SpecSync, Trust, provenance, macOS, Ubuntu, Linux smoke, and Windows checks pass.

## No-spec Rationale

Not applicable
