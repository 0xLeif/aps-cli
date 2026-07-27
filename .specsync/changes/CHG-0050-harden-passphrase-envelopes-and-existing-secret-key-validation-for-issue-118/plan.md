---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: plan
---

# Plan

1. Move swift-crypto to the reviewed `4.0.0..<4.4.0` range and add its public
   `CryptoExtras` product to the executable target.
2. Add a password-KDF abstraction backed by CryptoExtras scrypt with fixed
   constants, strict parameter validation, random 16-byte salts, and
   operation-scoped derived-key reuse.
3. Replace the single permissive envelope decoder with explicit legacy-v1 and
   strict-v2 models, including recipient-mode dispatch and exact field lengths.
4. Route new passphrase and key-file writes through v2 sealing while retaining
   v1 unlock compatibility.
5. Implement locked, verified, rollback-capable migration for successfully
   unlocked legacy passphrase envelopes.
6. Add `SecureKeyFile` native-handle implementations for POSIX and Windows,
   including ownership, type, permissions or ACL validation and safe repair.
7. Change encrypted watch polling to compare envelope snapshots before any
   passphrase KDF or decryption.
8. Remove production force tries and force casts touched by the audit and keep
   all new cross-boundary types `Sendable`.
9. Add deterministic crypto, migration, filesystem-race, permission, ACL,
   watch-cost, subprocess, and tri-OS regression tests.
10. Update README, security and dynamic-schema docs, schema output, dependency
    notes, and the aps-cli and state-store canonical specs.
11. Run `fledge lanes run verify`, strict SpecSync verification,
    `fledge trust verify`, provenance checks, and every hosted platform check.
