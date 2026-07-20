---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: design
---

# Design

- New `Sources/aps/SecretStore.swift`: `get` / `set` / `reset` /
  `hasSecret` over `secret.enc`. Missing file means the initial value;
  corrupt envelope throws `decodingFailed`; a valid envelope that does
  not open throws the new `APSError.secretUnlockFailed`.
- Recipient key: env passphrase (HKDF-SHA256, domain-separated salt/info)
  or generated key file (base64 X25519 raw, chmod 0600 on create).
- Envelope: fresh ephemeral pair per write; shared secret through
  HKDF-SHA256 ("aps-secret-store-v1" salt, "envelope" info).
- StateStore: `get` reads the store (initial on missing), `set` encrypts
  and read-back verifies, `reset` deletes the file; `freshValue(.secret)`
  reads directly so cross-process writes surface in watch;
  `requireDecodableDiskState` covers secret with loud corrupt/unlock
  failures.
- Package.swift adds apple/swift-crypto from 3.0.0.
