---
change: CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-001 | Seed keys listed by `aps keys` / smoke; `testUserSchemaMaterializeAndKeyAdd`; profile/secret round-trips in APSTests and smoke |
| REQ-aps-cli-005 | `testUnknownKeyError`; APSError cases exercised in invalid-value / corrupt / persistence smoke paths; schema_invalid / schema_conflict via key add |
| REQ-aps-cli-013 | `aps --version` equals `1.0.0` in smoke.sh and smoke.ps1; schema `cliVersion` asserted in smoke |
| REQ-aps-cli-019 | smoke greps `schemaVersion` 3, `userSchema`, and `unknown_key`; schema projection after key add lists smokeNote |
| REQ-aps-cli-021 | smoke `key add` / `set` / `get` / `key remove --purge` round-trip; `testUserSchemaMaterializeAndKeyAdd` |
| REQ-aps-cli-022 | smoke expects `schema.json` under APS_HOME; `testUserSchemaMaterializeAndKeyAdd` materializes defaults |
| REQ-state-store-002 | dump/dumpRegistered covered by APSTests dump tests and smoke dump; stats mutation uses string keys |
| REQ-state-store-016 | `testUserSchemaMaterializeAndKeyAdd`, `testUnknownKeyError`; registry get/set/reset via CLI smoke |

## Suites

- `swift test` (58 tests including schema materialize / unknown key)
- `./Scripts/smoke.sh` and `Scripts/smoke.ps1` (key add/remove + schemaVersion 3)
- `fledge lanes run verify`
