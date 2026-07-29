---
change: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
artifact: research
---

# Research

Foundation `JSONDecoder` accepts `1`, `1.0`, and `1e0` as both `Int(1)` and
`Double(1.0)`. Foundation `JSONEncoder` emits `Double(1.0)` as `1`. Therefore
generic Codable cannot preserve the lexical integer-versus-floating spelling.
The stable contract is structural JSON plus numeric value preservation, with
integral numeric forms permitted to canonicalize to Int.

StoredState tests use deterministic `Data` payloads because NSNumber bridging
differs across supported platforms.
