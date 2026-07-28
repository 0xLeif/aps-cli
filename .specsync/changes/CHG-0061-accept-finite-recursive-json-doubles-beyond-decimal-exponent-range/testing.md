---
change: CHG-0061-accept-finite-recursive-json-doubles-beyond-decimal-exponent-range
artifact: testing
---

# Testing

`DynamicObjectTypingTests.testFiniteDoublesBeyondDecimalRangeRemainSupported`
covers `1e-200` and the smallest positive subnormal Double. Existing tests keep
underflow and Decimal-range rounding rejection covered. The full native quality
lane must pass.
