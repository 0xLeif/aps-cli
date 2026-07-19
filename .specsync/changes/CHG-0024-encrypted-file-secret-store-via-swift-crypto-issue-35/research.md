---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: research
---

# Research

## Keychain prompt root cause

macOS Keychain grants durable item access per code signature. The `aps`
binary is ad-hoc signed in dev and its cdhash changes per build, so the
login Keychain re-prompts on every access; "Always Allow" cannot stick.
A stable Developer ID signature helps releases but not dev builds, and
says nothing for Windows/Linux. This matches the owner's report and the
pre-existing `APS_SMOKE_SECURESTATE=1` opt-out in smoke.

## Crypto construction survey

- AlgoChat `Sources/AlgoChat/Crypto/MessageEncryptor.swift` and
  `EphemeralKeyManager.swift`: pure swift-crypto (X25519 ephemeral ECDH +
  HKDF + ChaCha20-Poly1305, forward secrecy). Directly reusable as the
  reference construction.
- The `AlgoChat` library target depends on AlgoKit (Algorand SDK) via
  `KeyDerivation.swift`; taking the package as-is would drag a blockchain
  SDK with a dubious Windows story into aps. Decision 3ii (owner):
  depend on apple/swift-crypto directly and re-implement the same
  envelope (~1 file). swift-crypto is the tri-OS-safe base (BoringSSL
  everywhere; CryptoKit on Apple platforms).
- age/rage interop was considered and deferred: the store is consumed by
  aps itself; interop can arrive later as export/import.

## Passphrase vs key file

- Key file (0600) matches the SSH model: zero prompts, headless-safe,
  security equals filesystem permissions.
- Passphrase via env var keeps agents non-interactive; a TTY getpass
  prompt exists only as an opt-in fallback, never required.
