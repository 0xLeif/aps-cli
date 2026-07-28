---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: context
---

# Context

`SecretStore` currently writes an unversioned JSON envelope. Passphrase mode
turns the passphrase directly into an X25519 private key with HKDF-SHA256 and a
fixed salt. HKDF is suitable for expanding high-entropy key material, but it is
not a password-hardening function. Anyone who obtains `secret.enc` can test
passphrase guesses cheaply and offline.

The envelope also does not record whether its recipient is a passphrase or
`secret.key`. Unlock therefore depends on process environment rather than an
on-disk contract. Existing key files are parsed by path without first proving
that the opened object is an owned regular file with private permissions. A
symbolic-link substitution, permissive mode, foreign owner, Windows reparse
point, or permissive ACL can consequently be accepted as recipient material.

Issue #118 introduces a strict v2 envelope, scrypt password hardening, and
handle-based key-file validation. Existing unversioned v1 envelopes remain
readable. A successfully unlocked v1 passphrase envelope migrates to v2 as one
detected-error transaction; wrong credentials and migration failures leave the
original envelope byte-identical. Existing v1 key-file envelopes remain
compatible and migrate naturally on the next successful `set`.

scrypt at the selected parameters is deliberately expensive. Derivation is
cached only within one public SecretStore operation. Encrypted watch observes
the envelope bytes and does not decrypt an unchanged poll, preventing the poll
interval from multiplying KDF cost.

The guarantee covers errors detected before an API returns. It does not claim
crash or power-loss atomicity. The existing stable `decodingFailed`,
`secretUnlockFailed`, `persistenceFailed`, and rollback failure contracts
remain the public error boundary.
