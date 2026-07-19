---
change: CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64
artifact: plan
---

# Plan

1. UserSchema load/materialize/validate/write under state root.
2. Registry resolve for get/set/reset/dump/keys/watch by string name.
3. `aps key add|remove|list` with schema_invalid / unknown_key / schema_conflict.
4. Dynamic `aps schema` (schemaVersion 3, userSchema.hash).
5. Smoke + unit tests; move CI/Trust to macos-latest; scrub docs to 1.0.0.
