# state-store transactional reset and purge

## ADDED

### REQUIREMENT REQ-state-store-022

StateStore reset and purge operations SHALL be transactional for errors
detected before return. Schema purge SHALL acquire the schema lock before the
storage lock, restore the original schema on detected purge failure, and report
rollback failure distinctly. Storage resets SHALL verify their postconditions
before recording success.

Acceptance Criteria
- FileState reset atomically overwrites the initial value under its per-file
  lock without deleting the old file first.
- Secret reset throws, holds `secret.store.lock`, removes and verifies only the
  envelope leaf, and preserves shared `secret.key` material.
- Schema removal plus purge holds `schema.json.lock` through candidate write,
  storage deletion, verification, and any original-schema rollback.
- Concurrent APS schema mutation cannot reuse a purged path during the
  transaction.
- Successful rollback rethrows the original purge error; failed rollback emits
  a distinct stable rollback error.
- Bulk reset stops at the first failure, identifies reset, failed, and
  not-attempted keys, and records stats only for successful keys.
