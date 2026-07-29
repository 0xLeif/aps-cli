# state-store watch and persisted numeric-kind corrections

## ADDED

### REQUIREMENT REQ-state-store-028

Encrypted watch SHALL validate decrypted initial, fallback, updated, and
deletion-fallback plaintext against the registered schema before accepting or
emitting it. StoredState reads SHALL preserve the declared Bool-versus-Int kind
when Foundation represents values as NSNumber and SHALL reject cross-kind
objects as `corrupt_state`.

Acceptance Criteria
- Invalid initial encrypted plaintext is not emitted.
- Invalid updated encrypted plaintext is not emitted after a valid event.
- NSNumber booleans cannot decode as StoredState Int values.
- NSNumber integers cannot decode as StoredState Bool values.
- Focused regressions and the full quality lane pass.
