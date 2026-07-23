---
id: CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations
state: accepted
type: bug_fix
base_commit: 6a40258d80047be13132e68b0597ff3bfe9b52b7
---

# Serialize cross-process FileState and Slice profile read-modify-write operations

## Intent

Serialize cross-process FileState and Slice profile read-modify-write operations

## Affected Canonical Specs

- `state-store`
- `aps-cli`

## Acceptance Criteria

- Concurrent profile and profileName CLI writes produce valid profile JSON with version 99 preserved; per-file locks serialize DynamicKeyStorage FileState and Slice writes; fledge lanes run verify passes

## No-spec Rationale

Not applicable
