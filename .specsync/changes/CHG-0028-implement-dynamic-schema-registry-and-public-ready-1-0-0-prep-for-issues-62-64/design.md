---
change: CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64
artifact: design
---

# Design

Implements `docs/design/dynamic-schema.md`: on-disk schema.json, demo seed materialization,
registry-backed storage adapters, CLI string keys, key mutation sugar, schemaVersion 3
with userSchema.hash. Static schemaVersion bumps only when the schema document shape changes.
