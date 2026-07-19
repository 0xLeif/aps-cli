---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: plan
---

# Plan

1. Add swift-crypto to Package.swift; write SecretStore.swift (envelope,
   recipient key modes, get/set/reset).
2. Wire StateStore secret paths (get/set/reset/freshValue/requireDecodable);
   remove SecureState extension, APSKeychain, keychainUnavailable case.
3. Tests: round-trip, reset deletes file, 0600 perms, corrupt envelope,
   cross-instance persistence, passphrase round-trip + wrong key.
4. Smoke: key-file round-trip, perms, reset, passphrase right/wrong.
5. Specs (both modules), README, GOAL, windows-readiness in lockstep.
