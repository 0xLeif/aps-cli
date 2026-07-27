---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: design
---

# Design

Route every string-key operation through the resolved `SchemaKeyEntry` and
`DynamicKeyStorage`, regardless of whether the name appears in `DemoKey`.
Remove name-based branches from get, set, reset, disk validation, watch, and
typed output.

`reset --all` continues to mean the seed-name scope, but it intersects that
scope with the current registry. Each matching entry resets through its current
type, storage, path, Slice metadata, and initial value. Removed seed names are
not recreated and their old data is not touched. `reset --registered` continues
to reset every current entry through the same adapter.

Default FileState, EncryptedFile, and Slice entries retain their existing paths
and wire formats. Dynamic StoredState uses `aps.user.<name>`. For the unchanged
default `flag` entry, reads fall back to AppState's legacy `App/aps.flag` key
when the canonical key is absent; reset clears both keys. Forced entries do not
inherit this compatibility fallback unless their behavioral definition still
matches the default flag.

Direct `DemoKey` APIs remain a low-level AppState dogfood surface, but CLI
registry commands and registry output never call them. General recursive JSON
object output and stronger object/Slice validation remain owned by issue #114;
this change proves that a forced seed entry uses its current declared type
rather than its compiled seed type.
