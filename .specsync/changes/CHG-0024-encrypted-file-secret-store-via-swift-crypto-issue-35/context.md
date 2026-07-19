---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: context
---

# Context

Issue #35 (design decision 3ii). The Keychain-backed `secret` prompted for
the macOS password on every access: an ad-hoc signed CLI can never earn
durable Keychain trust, and SecureState says nothing for Windows/Linux.
The fix is an encrypted-file store under the state root, prompt-free and
tri-OS.

## Decisions

- swift-crypto directly (no AlgoKit): ephemeral X25519 ECDH + HKDF +
  ChaCha20-Poly1305, AlgoChat's Crypto/ as the reference construction.
- Custom JSON envelope (ephemeral public key, nonce, ciphertext, tag as
  base64); age interop deferred to a later export/import.
- Unlock model: key file `<state-root>/secret.key` (0600) by default;
  `APS_SECRET_PASSPHRASE` opt-in via HKDF-SHA256; TTY getpass fallback
  when `APS_SECRET_USE_PASSPHRASE=1`. Agents always non-interactive.
- AppState `SecureState` and `APSKeychain` are removed; the dead
  `keychainUnavailable` case goes with them (the #42 lesson applied).
- Write-then-read-back verification kept from the #27 pattern.
