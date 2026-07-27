# aps-cli truthful reset and purge failures

## ADDED

### REQUIREMENT REQ-aps-cli-029

Reset and purge commands SHALL report every detected persistence failure
through the stable error contract and SHALL NOT emit success output after a
failure. Bulk reset SHALL fail fast in schema order and report successfully
reset, first-failed, and not-attempted keys.

Acceptance Criteria
- Wrong-kind, deletion, replacement, postcondition, and rollback failures exit
  nonzero with stable machine codes.
- Machine failures keep stdout empty and emit one structured error on stderr.
- A partial bulk result contains `reset`, `failed`, and `notAttempted`.
- Mutation statistics count only keys whose reset postcondition succeeded.
- Documentation limits transaction guarantees to errors detected before API
  return and does not claim crash or power-loss atomicity.
