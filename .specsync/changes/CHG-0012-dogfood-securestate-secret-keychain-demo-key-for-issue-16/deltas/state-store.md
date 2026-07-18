# State Store SecureState secret dogfood

## ADDED

### REQUIREMENT REQ-state-store-013

`StateStore` SHALL expose `secret` as Keychain-backed `SecureState` with account `dev.leif.aps/secret`, verify Keychain read-back after set, and delete the item on reset.

Acceptance Criteria
- Round-trip get/set works on macOS.
- `reset(.secret)` leaves get as "" and removes the Keychain item.
- Without Security, `set(.secret, ...)` throws `APSError.keychainUnavailable`.
