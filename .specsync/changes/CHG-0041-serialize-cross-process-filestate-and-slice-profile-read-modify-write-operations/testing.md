---
change: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-state-store-019 | smoke concurrent `profile` and `profileName` writes; `SchemaFileLock.withExclusiveLock`; DynamicKeyStorage FileState/Slice write paths |
| REQ-aps-cli-025 | `SchemaFileLock` preserves the public schema lock API and serializes profile file writes |

The smoke suite starts concurrent `profile` and `profileName` writers under one `APS_HOME` and verifies valid JSON plus preservation of `version:99`. The full `fledge lanes run verify` gate covers build, unit tests, smoke, and plugin validation.
