---
change: CHG-0059-reject-underflowing-recursive-json-numbers-instead-of-coercing-them-to-zero
artifact: context
---

# Context

Foundation JSONDecoder may decode a nonzero number below Double range, such as
`1e-400`, as Int zero. The recursive JSON decoder must reject that coercion to
preserve the existing exact-value contract.
