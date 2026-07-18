# aps-cli Slice profileName dogfood

## MODIFIED

### REQUIREMENT REQ-aps-cli-016

`profileName` SHALL read and write `ProfileDocument.name` through an AppState `Slice` over `profile`.

Acceptance Criteria
- `aps set profileName X` updates the parent `profile` document name on disk.
- `aps get profileName` returns the current parent name field.
- `aps keys` lists `profileName` with storage `Slice`.
