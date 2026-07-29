---
id: CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t
state: accepted
type: bug_fix
base_commit: 058730a6bbf22e4a9d1bda3755b12e5a8040dec7
---

# Close remaining PR 129 validation gaps for encrypted watch, Slice shapes, Bool tokens, and StoredState numeric kinds

## Intent

Close remaining PR 129 validation gaps for encrypted watch, Slice shapes, Bool tokens, and StoredState numeric kinds

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Encrypted watch rejects invalid initial and updated decrypted values before emission; schema validation rejects parent initials and sibling Slice definitions with incompatible nested object shapes; direct parent writes satisfy every Slice shape before mutation; Bool parsing accepts y and n consistently; StoredState rejects Bool and Int NSNumber cross-kind bridging; canonical specs list every SchemaJSON case; all serial, parallel, smoke, and trust gates pass.

## No-spec Rationale

Not applicable
