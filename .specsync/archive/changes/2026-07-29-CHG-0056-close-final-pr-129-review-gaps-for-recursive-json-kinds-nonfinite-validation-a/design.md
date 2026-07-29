---
change: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
artifact: design
---

# Design

Keep `SchemaJSON` structural and use JSON-standard numeric semantics. Int and
Double remain useful Swift cases for declared validation, but equivalent
integral JSON tokens may canonicalize to Int after Codable decoding.

Add a recursive finite-value predicate and require it before declared-type and
open-shape validation. Update the shared schema payload node once so every
value-bearing payload advertises the same recursive union.

For StoredState reads, snapshot the raw object once. Absence selects the
initial; presence must decode or throw `corrupt_state`. Write/reset
postcondition helpers retain their optional persisted-value interface.
