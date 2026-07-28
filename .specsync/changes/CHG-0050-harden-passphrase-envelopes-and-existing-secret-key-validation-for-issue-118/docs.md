---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: docs
---

# Docs

Update README secret examples and the CLI schema description to state that new
envelopes are v2, mode-bound, and use scrypt for passphrases. Keep examples free
of real passphrases and explain that `APS_SECRET_PASSPHRASE` remains visible to
the environment of the command.

Add or update security documentation with:

- the exact scrypt contract: `N=131072`, `r=8`, `p=1`, 32-byte output,
  16-byte random per-write salt, and approximately 128 MiB of KDF memory;
- the supported envelope versions and strict `recipientMode` behavior;
- automatic transactional migration for successfully unlocked legacy
  passphrase envelopes and next-write upgrade for legacy key-file envelopes;
- the wrong-credential and migration-failure guarantee that original envelope
  bytes remain unchanged when rollback succeeds;
- POSIX owner and exact `0600` requirements, plus Windows owner, non-reparse,
  regular-file, and protected ACL requirements;
- the fact that APS may safely repair permissions or ACLs only after proving
  ownership and regular-file identity through an open handle;
- unchanged encrypted watch polling avoids repeated scrypt work.

Update `docs/design/dynamic-schema.md` for v2 EncryptedFile envelopes,
operation-scoped recipient contexts, store-lock migration, and shared
`secret.key` validation. Update `docs/release-readiness.md` to identify issue
#118 as completed only after the implementation, tri-OS evidence, and
canonical spec updates merge.

Dependency documentation and notices must identify apple/swift-crypto
`4.0.0..<4.4.0` and the public CryptoExtras scrypt product. Do not describe the
scheme as equivalent to age, claim memory locking or zeroization that Swift
does not guarantee, or claim crash/power-loss atomicity.
