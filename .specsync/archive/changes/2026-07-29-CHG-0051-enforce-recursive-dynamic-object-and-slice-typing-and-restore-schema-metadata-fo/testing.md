---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-019 | `APSTests` schema contract cases and both smoke scripts |
| REQ-aps-cli-024 | `APSTests` version, keyCount, and flag cases plus both smoke scripts |
| REQ-aps-cli-033 | `DynamicObjectTypingTests` plus shaped object and Slice smoke round trips |
| REQ-state-store-022 | `APSTests` transactional reset, purge, rollback, lock, and adapter cases |
| REQ-state-store-026 | `DynamicObjectTypingTests` plus shaped Slice unit and smoke cases |

The complete local gate is `fledge lanes run verify`. Strict SpecSync verification
must record exact evidence for both `aps-cli` and `state-store`.

## Current Evidence

- `Tests/apsTests/DynamicObjectTypingTests.swift` covers recursive JSON,
  structural CLI output, initial and shape rejection, forward Slice references,
  pre-mutation FileState rejection, and typed Slice round trips.
- `Tests/apsTests/APSTests.swift` covers schema version 6,
  `userSchema.keyCount`, `--field` advertisement, registry authority, declared
  Slice fields, and transactional reset compatibility.
- `fledge lanes run verify` passes all seven steps locally with 222 serial and
  222 parallel tests plus the expanded Unix smoke.
- PowerShell smoke parser validation passes; hosted Windows execution remains
  pending.
- Strict SpecSync, Trust, provenance, and hosted gates remain pending.
