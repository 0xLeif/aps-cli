---
change: CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext
artifact: plan
---

# Plan

1. Reject non-exact integral Double fallbacks during recursive JSON decoding.
2. Validate decrypted plaintext in encrypted disk-state preflight.
3. Add focused regressions and update both canonical requirements.
4. Run the full native quality gate and strict SpecSync check.
