---
change: CHG-0060-reject-fractional-recursive-json-values-when-double-encoding-would-change-their
artifact: testing
---

# Testing

`DynamicObjectTypingTests.testFractionRoundedToIntegralDoubleIsRejected`
covers the reported precision loss. Existing numeric tests cover ordinary
finite doubles, integral canonicalization, underflow, and oversized integers.
The full native quality lane must pass.
