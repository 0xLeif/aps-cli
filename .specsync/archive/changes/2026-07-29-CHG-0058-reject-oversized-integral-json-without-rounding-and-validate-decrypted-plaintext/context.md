---
change: CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext
artifact: context
---

# Context

PR #129 review found two final validation gaps. JSON integers outside native Int
range fell through to Double and could round to a different value. Encrypted
disk-state preflight decrypted envelopes but did not validate plaintext against
the current registered schema.
