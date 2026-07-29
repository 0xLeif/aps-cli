---
id: CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext
state: archived
type: bug_fix
base_commit: b9b9977e85a064f1b05e6077e87a3c8316a55290
---

# Reject oversized integral JSON without rounding and validate decrypted plaintext during encrypted disk-state preflight

## Intent

Reject oversized integral JSON without rounding and validate decrypted plaintext during encrypted disk-state preflight

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Out-of-range integral JSON decoding fails instead of rounding through Double; encrypted disk-state preflight rejects decryptable schema-incompatible plaintext as corrupt_state; focused regressions and the full quality lane pass.

## No-spec Rationale

Not applicable
