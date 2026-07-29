---
change: CHG-0060-reject-fractional-recursive-json-values-when-double-encoding-would-change-their
artifact: context
---

# Context

Foundation may decode a high-precision fractional JSON number as a rounded
Double. Recursive values must reject the token if encoding that Double changes
the original Decimal value.
