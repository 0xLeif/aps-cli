---
change: CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t
artifact: requirements
---

# Requirements

1. Encrypted watch SHALL schema-validate initial, fallback, updated, and
   deletion-fallback plaintext before accepting or emitting it.
2. A parent FileState initial and every direct parent write SHALL satisfy each
   nested object Slice shape targeting its fields.
3. Sibling object Slices targeting the same parent field SHALL declare the
   same object shape.
4. Dynamic Bool parsing SHALL accept every token accepted by the central Bool
   parser, including `y` and `n`.
5. StoredState reads SHALL reject Bool-as-Int and Int-as-Bool NSNumber
   representations as `corrupt_state`.
6. The canonical aps-cli terminology SHALL list every public SchemaJSON case.
7. Focused regressions, serial and parallel tests, smoke checks, strict
   SpecSync, and hosted platform gates SHALL pass.
