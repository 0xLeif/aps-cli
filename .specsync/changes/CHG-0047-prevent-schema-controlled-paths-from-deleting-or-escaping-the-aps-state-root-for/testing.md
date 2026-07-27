---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-027 | `testSchemaRejectsStateRootAndPreservesSentinel`, `testSchemaRejectsPortableStoragePathCollision`, `testNestedStoragePathRoundTripsAndResets`; `Scripts/smoke.sh` and `Scripts/smoke.ps1` preserve a state-root sentinel during the original `EncryptedFile` path `.` attack |
| REQ-state-store-020 | `SchemaStoragePathTests` covers lexical rejection, reserved names, Unicode/case collision keys, canonical nested resolution, directory/symlink/special-file rejection, missing-leaf no-op, and regular-file-only deletion; `testParallelSchemaPathCollisionAllowsOneWinner` proves collision validation under the schema lock |

## Suites

- Unit-test rejected lexical paths, reserved names, portable collisions, and
  accepted nested paths.
- Test existing directory, symbolic-link leaf, symbolic-link ancestor, special
  file, missing leaf, and regular-file deletion behavior.
- Reproduce the original EncryptedFile `.` purge attack and assert that a state
  root sentinel survives.
- Exercise FileState and EncryptedFile reset/purge with valid paths.
- Run parallel adds claiming one portable collision key and require one winner.
- Run `fledge lanes run verify`.
- Run the change verification and `fledge trust verify`.
- Require macOS, Linux, and Windows GitHub checks.
