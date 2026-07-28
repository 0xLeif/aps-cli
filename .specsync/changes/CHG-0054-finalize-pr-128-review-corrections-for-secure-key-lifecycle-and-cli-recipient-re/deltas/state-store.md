# state-store resolved entry return

## ADDED

### REQUIREMENT REQ-state-store-024

A successful string-name `StateStore.set(name:value:)` SHALL return the exact
`SchemaKeyEntry` resolved while the schema lock is held.

Acceptance Criteria
- The returned entry equals the resolved schema definition used for the
  successful storage mutation.
- Callers that ignore the return value remain source-compatible.
