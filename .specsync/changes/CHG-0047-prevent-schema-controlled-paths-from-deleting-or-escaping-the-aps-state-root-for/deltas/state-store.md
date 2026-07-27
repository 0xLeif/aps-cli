# state-store verified schema storage paths

## ADDED

### REQUIREMENT REQ-state-store-020

Every schema-controlled filesystem operation SHALL resolve its path through one
validated storage-path abstraction, re-check canonical containment and existing
path components at operation time, and delete only a verified regular leaf
file.

Acceptance Criteria
- Existing directory, symbolic-link, and special-file leaves are rejected
  without mutation.
- Existing symbolic-link ancestors cannot redirect operations outside the
  state root.
- Missing leaf deletion is a successful no-op.
- Complete-schema validation serializes portable collision checks under the
  schema lock.
