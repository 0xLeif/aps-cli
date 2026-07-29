---
change: CHG-0061-accept-finite-recursive-json-doubles-beyond-decimal-exponent-range
artifact: context
---

# Context

Decimal has a narrower exponent range than Double. A successful finite Double
decode must remain supported when Decimal cannot represent the same token,
while Decimal comparison still guards precision where available.
