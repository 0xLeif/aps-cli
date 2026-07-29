# state-store encrypted preflight correction

## MODIFIED

### REQUIREMENT REQ-state-store-028

Encrypted watch SHALL validate decrypted initial, fallback, updated, and
deletion-fallback plaintext against the registered schema before accepting or
emitting it. StoredState reads SHALL preserve the declared Bool-versus-Int kind
when Foundation represents values as NSNumber and SHALL reject cross-kind
objects as `corrupt_state`. Encrypted disk-state preflight SHALL validate
decrypted plaintext against the registered schema.

Acceptance Criteria
- Invalid initial encrypted plaintext is not emitted.
- Invalid updated encrypted plaintext is not emitted after a valid event.
- NSNumber booleans cannot decode as StoredState Int values.
- NSNumber integers cannot decode as StoredState Bool values.
- Schema-incompatible decrypted plaintext fails disk-state preflight as corrupt.
- Focused regressions and the full quality lane pass.
