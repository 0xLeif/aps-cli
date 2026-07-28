---
change: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
artifact: plan
---

# Plan

1. Correct the numeric semantics and review findings in successor contracts.
2. Implement recursive finiteness, schema self-description, and StoredState
   presence-aware decoding.
3. Add deterministic unit coverage without platform-sensitive NSNumber casts.
4. Run the full local lane, strict contract scan, and hosted gates.
