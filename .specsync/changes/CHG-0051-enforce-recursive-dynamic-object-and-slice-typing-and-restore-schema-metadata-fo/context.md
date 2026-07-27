---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: context
---

# Context

Issue #114 is a v1.1.0 release blocker. Registered object values currently
remain raw strings through storage and are converted to machine JSON only when
they happen to decode as `ProfileDocument`. Other objects are emitted as JSON
strings, while profile-shaped objects can lose undeclared fields because
`JSONDecoder` ignores them.

`schema.json` validation currently checks names, broad type/storage membership,
paths, and the existence of a FileState object parent for Slice entries. It
does not prove that initials match declared types, object shapes contain valid
field types, a Slice field exists in its parent shape, or parent and Slice
types agree. The `key add` command always writes an empty object shape and
parses every Slice initial as a string.

The public `aps schema` contract and README already promise
`userSchema.keyCount`, but the encoder omits it. Adding the missing field changes
the schema document shape, so `schemaVersion` must move from 5 to 6.

This change is stacked on the accepted issue #118 head so it owns SpecSync
sequence 51 without colliding with CHG-0050. It will rebase onto main after
PR #128 and the CHG-0050 archive land.
