---
change: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
artifact: context
---

# Context

Final review of PR #129 found four contract gaps:

- Foundation Codable cannot preserve the lexical difference between integral
  JSON forms such as `1`, `1.0`, and `1e0`.
- Recursive arrays and open object extensions can hide nonfinite doubles from
  schema validation.
- Schema version 6 advertises an incomplete set of recursive JSON kinds.
- A present but undecodable StoredState object silently falls back to the
  schema initial.

This successor change corrects those gaps without editing accepted CHG-0051.
