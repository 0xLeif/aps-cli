---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: design
---

# Design

## Shared recursive JSON

Promote `SchemaJSON` into the single recursive wire value used by schema
initials and `CLIOutput`. Add null, finite floating-point, and array cases while
retaining the existing string, integer, boolean, and object cases. Decode Bool
before numeric values and Int before Double so Swift/Foundation bridging cannot
turn booleans into integers. Reject non-finite doubles. `wireString` uses sorted
JSON for structured values.

Storage APIs remain string-based at their public boundary for compatibility.
They parse and validate through the shared value before dispatch and after
reads. This keeps the change focused while eliminating the lossy
`ProfileDocument` special case.

## Schema validation

Validation runs in two passes. The first validates each entry locally:
names, storage, path, metadata applicability, initial type, object-shape type
names, and object initial shape. The second resolves Slice references so forward
references remain valid.

Object shapes are open: every declared field is required and type-checked, while
undeclared fields are preserved. This gives shapes useful guarantees without
destroying arbitrary JSON extension fields. A Slice field must be explicitly
declared by its parent shape; the former unshaped fallback is rejected because
issue #114 requires provable field existence.

## CLI shape UX

`key add` accepts repeated `--field NAME=TYPE`. Each token splits at its first
`=`, uses the schema key-name grammar for field names, accepts the supported
field types, and rejects duplicates. `--field` is valid only for object keys.
Object keys require at least one field when they are a Slice parent; standalone
objects may use an empty open shape.

## Runtime and contract

Dynamic storage validates requested values before any adapter mutation.
FileState object reads decode and validate structural JSON and map invalid disk
state to `corrupt_state`. Slice reads validate the stored field against the
declared type; Slice sets parse through the same shared helper.

`CLIOutput.JSONValue` becomes a type alias to the recursive JSON value. Demo
profile output is decoded generically, preserving the same wire shape while
removing domain coupling.

`Schema.UserSchemaMeta` gains `keyCount`, populated from `schema.keys.count` in
both live and static documents. `schemaVersion` becomes 6.
