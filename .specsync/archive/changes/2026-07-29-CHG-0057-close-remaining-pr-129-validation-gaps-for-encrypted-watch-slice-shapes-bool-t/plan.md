---
change: CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t
artifact: plan
---

# Plan

1. Route encrypted watch plaintext through shared schema validation.
2. Enforce nested Slice shapes at schema load and direct parent mutation.
3. Restore complete Bool tokens and reject cross-kind NSNumber reads.
4. Complete canonical SchemaJSON terminology.
5. Add regressions and run every quality and contract gate.
