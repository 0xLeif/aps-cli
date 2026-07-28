---
change: CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext
artifact: design
---

# Design

After Int decoding fails, accept a finite Double only when it is non-integral or
still exactly representable as Int. This rejects rounded oversized integral
values. During encrypted preflight, pass decrypted plaintext through the same
schema read validator used by normal registered reads.
