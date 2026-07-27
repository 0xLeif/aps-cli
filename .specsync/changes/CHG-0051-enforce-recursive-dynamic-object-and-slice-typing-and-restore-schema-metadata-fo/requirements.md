---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: requirements
---

# Requirements

1. One recursive `Codable`, `Equatable`, and `Sendable` JSON value SHALL
   represent null, boolean, integer, finite floating-point, string, array, and
   object values without depending on a domain model.
2. All machine outputs for registered keys SHALL preserve recursive object
   structure and every field through get, set, dump, watch, and reset.
3. Every schema initial SHALL match its declared top-level type. Object initials
   SHALL be objects, contain every declared shape field with the declared type,
   and MAY retain undeclared fields.
4. Object shapes SHALL use supported field type names and SHALL be rejected on
   non-object entries. Runtime object reads and writes SHALL enforce the same
   declared shape before returning or mutating state.
5. A Slice SHALL name an existing FileState object parent and a nonempty field
   declared in the parent object shape. The parent field type, Slice type, and
   Slice initial SHALL agree. Object-valued Slices SHALL validate against their
   own object shape.
6. Slice-only metadata SHALL be rejected on non-Slice entries, ignored path
   metadata SHALL be rejected on Slice entries, and every Slice SHALL have a
   typed initial.
7. `aps key add` SHALL accept repeatable `--field NAME=TYPE` options for object
   shapes, reject malformed or duplicate declarations, and parse initials by
   declared type for every storage adapter.
8. `aps schema` SHALL include `userSchema.keyCount`, equal to both the active
   registry count and projected key count, and SHALL advertise
   `schemaVersion: 6`.
9. Existing valid default keys, recursive objects, registry authority,
   transactional reset, locking, and error contracts SHALL remain compatible.
   Previously accepted invalid unshaped or mismatched Slice definitions SHALL
   fail as `schema_invalid` before state mutation.
