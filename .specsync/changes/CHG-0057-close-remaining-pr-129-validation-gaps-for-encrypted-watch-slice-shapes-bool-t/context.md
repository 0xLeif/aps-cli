---
change: CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t
artifact: context
---

# Context

Final review of PR #129 found remaining paths that bypassed the recursive
schema contract:

- encrypted watch decrypted and emitted values without schema validation;
- object Slice shapes were not enforced against parent initials, sibling
  Slice declarations, or direct parent writes;
- the new Bool parser omitted the existing `y` and `n` tokens;
- Foundation NSNumber bridging could convert Bool and Int StoredState values;
- the canonical terminology omitted the public array and object cases.

This successor change closes those gaps without editing accepted CHG-0051 or
CHG-0056.
