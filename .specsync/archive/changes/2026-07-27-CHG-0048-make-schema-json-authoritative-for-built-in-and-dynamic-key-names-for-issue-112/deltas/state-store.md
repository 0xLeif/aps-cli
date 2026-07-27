# state-store uniform registry dispatch

## ADDED

### REQUIREMENT REQ-state-store-021

String-key state operations SHALL use one uniform registry dispatch path for
default and user-added names. The resolved entry SHALL select type, storage,
path, initial value, Slice metadata, disk validation, polling, and reset
behavior.

Acceptance Criteria
- A seed name forced to another supported type or adapter uses only the forced
  definition.
- FileState and EncryptedFile paths come from the current entry.
- Slice reads and writes use the current parent and field.
- The unchanged default flag remains readable from legacy AppState StoredState
  data when no canonical dynamic value exists, and reset prevents resurrection.
