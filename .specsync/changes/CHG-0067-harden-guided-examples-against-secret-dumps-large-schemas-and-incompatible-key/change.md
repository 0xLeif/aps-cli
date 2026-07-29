---
id: CHG-0067-harden-guided-examples-against-secret-dumps-large-schemas-and-incompatible-key
state: accepted
type: bug_fix
base_commit: 488b54ab6170c05fa44aa43842aac14aad9c5133
---

# Harden guided examples against secret dumps, large schemas, and incompatible key collisions

## Intent

Harden guided examples against secret dumps, large schemas, and incompatible key collisions

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Agent startup avoids full-state dumps; both helpers consume complete key inventories; incompatible pre-existing checkpoint keys fail safely; regression tests cover each boundary.

## No-spec Rationale

This hardens runnable examples and documentation without changing the aps CLI contract.
