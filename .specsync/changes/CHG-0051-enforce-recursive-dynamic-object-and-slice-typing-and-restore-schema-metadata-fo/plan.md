---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: plan
---

# Plan

1. Generalize `SchemaJSON` and centralize declared-type/object-shape validation.
2. Strengthen two-pass schema and Slice validation.
3. Replace domain-specific CLI object encoding with the shared recursive value.
4. Enforce typed values at every dynamic storage boundary.
5. Add repeatable `key add --field NAME=TYPE` object-shape UX.
6. Add `userSchema.keyCount` and bump the contract to schema version 6.
7. Add focused unit, CLI, smoke, and contract regression coverage.
8. Update README, dynamic-schema design, release readiness, canonical specs,
   and semantic deltas.
9. Run serial and parallel tests, smoke on Unix and Windows, strict SpecSync,
   Trust, provenance, and hosted macOS/Linux/Windows gates.
