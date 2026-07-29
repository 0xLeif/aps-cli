---
change: CHG-0059-reject-underflowing-recursive-json-numbers-instead-of-coercing-them-to-zero
artifact: testing
---

# Testing

`DynamicObjectTypingTests.testUnderflowingJSONNumberIsRejectedInsteadOfZeroed`
covers positive and negative underflow. The existing recursive numeric tests
cover ordinary zero, integral canonicalization, finite doubles, and oversized
integral rejection. The full native quality lane must pass.
