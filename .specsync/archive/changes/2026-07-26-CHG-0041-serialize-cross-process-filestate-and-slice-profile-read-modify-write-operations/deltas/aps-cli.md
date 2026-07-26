# aps-cli shared file locking

## ADDED

### REQUIREMENT REQ-aps-cli-025

The shared file lock helper SHALL support exclusive locks for each state file
used by a read-modify-write operation, while preserving the existing schema
lock API.

Acceptance Criteria
- Schema mutations continue to use `schema.json.lock`.
- FileState and Slice writes can serialize on `profile.json.lock`.
