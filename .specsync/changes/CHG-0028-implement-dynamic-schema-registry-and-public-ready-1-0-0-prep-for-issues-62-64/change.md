---
id: CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64
state: accepted
type: feature
base_commit: c5c36dc544afbbebddcb8765c3e60b6a46980495
---

# Implement dynamic schema registry and public-ready 1.0.0 prep for issues 62-64

## Intent

Implement dynamic schema registry and public-ready 1.0.0 prep for issues 62-64

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- schema.json materializes; string-key get/set/reset/dump/keys/watch; aps key add|remove|list; aps schema schemaVersion 3 with userSchema.hash; smokes green; CI/Trust on macos-latest; version/docs 1.0.0; #40 flip deferred.

## No-spec Rationale

Not applicable
