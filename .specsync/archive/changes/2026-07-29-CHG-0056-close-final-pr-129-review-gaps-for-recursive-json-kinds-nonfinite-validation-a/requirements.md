---
change: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
artifact: requirements
---

# Requirements

1. Recursive values SHALL preserve JSON structure and numeric value. They
   SHALL NOT promise lexical preservation between integral forms `1`, `1.0`,
   and `1e0`, because Foundation Codable and JSON semantics do not expose a
   stable numeric subtype for those equivalent values.
2. Schema validation SHALL reject a nonfinite double at any array or object
   depth, including undeclared fields retained by an open object shape.
3. Schema version 6 SHALL advertise null, boolean, integer, finite number,
   string, array, and object as recursive payload kinds.
4. An absent StoredState object SHALL use its schema initial. A present object
   that cannot decode as the declared type SHALL fail as `corrupt_state`
   without falling back.
5. Focused regressions, the full local quality lane, strict SpecSync, and every
   hosted platform gate SHALL pass.
