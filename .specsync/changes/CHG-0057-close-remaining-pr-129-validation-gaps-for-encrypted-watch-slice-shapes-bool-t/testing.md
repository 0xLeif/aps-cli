---
change: CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t
artifact: testing
---

# Testing

Focused tests cover invalid initial and updated encrypted-watch plaintext,
parent initials that violate nested Slice shapes, incompatible and compatible
sibling Slice shapes, invalid direct parent writes, short Bool tokens, and
cross-kind NSNumber StoredState objects. Final verification runs 261 serial
tests, 261 parallel tests, smoke, CI dogfood, installer action checks, plugin
validation, strict SpecSync, and hosted Linux, macOS, and Windows workflows.

| Requirement | Evidence |
|---|---|
| REQ-aps-cli-035 | `DynamicObjectTypingTests` covers Bool tokens, parent initials, sibling shapes, and direct parent writes; the canonical terminology diff covers array and object |
| REQ-state-store-028 | `SecretStoreSecurityTests` covers invalid encrypted watch values and `APSTests` covers cross-kind NSNumber StoredState reads |
