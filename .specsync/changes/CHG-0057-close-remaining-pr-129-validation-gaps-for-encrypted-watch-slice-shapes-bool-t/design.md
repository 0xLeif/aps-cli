---
change: CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t
artifact: design
---

# Design

Use the existing `DynamicKeyStorage.validateReadValue` path for encrypted
watch so normal reads and watch share error mapping. Validate object Slice
constraints both when loading the schema and before direct parent mutation.
Require exact sibling object-shape equality because either Slice can replace
the shared field. Delegate Bool token parsing to `StateStore.parseBool`.
Inspect Core Foundation NSNumber type identifiers before Swift bridging to
distinguish booleans from integers.
