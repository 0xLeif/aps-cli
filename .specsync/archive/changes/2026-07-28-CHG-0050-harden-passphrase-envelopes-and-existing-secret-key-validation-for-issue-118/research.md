---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: research
---

# Research

The security and portability audit established the following constraints:

- The fixed-context HKDF passphrase derivation provides no configurable work
  factor and permits inexpensive offline guessing. The envelope needs a random
  salt and a password KDF with bounded, validated parameters.
- apple/swift-crypto 4.x exposes scrypt through the public `CryptoExtras`
  product. Pinning the dependency to `4.0.0..<4.4.0` supplies one supported
  implementation on macOS, Linux, and Windows without private SPI or a second
  C-backed package.
- `N=131072`, `r=8`, `p=1`, and 32 output bytes provide a fixed release
  contract. The approximate scrypt memory requirement is 128 MiB. Values from
  disk must never select a larger computation.
- A random 16-byte salt belongs to each newly sealed passphrase envelope. It is
  not secret, must be authenticated by successful envelope opening, and must
  be regenerated for every passphrase-mode rewrite.
- X25519 still requires a deterministic 32-byte private-key representation.
  scrypt therefore derives exactly 32 bytes, which are validated by
  `Curve25519.KeyAgreement.PrivateKey`.

The existing unversioned JSON shape cannot distinguish passphrase and key-file
recipients. Compatibility must use the active legacy selection rule only for
v1. A v2 `recipientMode` prevents fallback between recipient classes and
prevents a missing key file from being created while opening passphrase data.

Path-based `Data(contentsOf:)`, attribute checks, and later reads contain a
time-of-check/time-of-use gap. The key object must be opened once and all type,
ownership, permission, and data checks performed through that handle:

- macOS and Linux use `lstat` as an early rejection, `open` with
  `O_NOFOLLOW | O_CLOEXEC`, then `fstat`. The handle must identify a regular
  file owned by the effective user. Group and other permission bits are
  repaired to mode `0600` with `fchmod` only after ownership and type are
  proven, then verified again with `fstat`.
- Windows uses `CreateFileW` with `FILE_FLAG_OPEN_REPARSE_POINT`, rejects the
  reparse attribute and non-disk or directory handles, verifies the owner SID
  equals the current process user, and inspects the DACL. A safely owned
  regular file can receive an owner-only DACL through the open handle and must
  be reverified. Foreign-owned, reparse, wrong-kind, or unrepairable objects are
  rejected without replacing or truncating them.
- Creation uses exclusive create semantics and private permissions or a
  private security descriptor at creation time. It then verifies the created
  handle before writing base64 key bytes.

Legacy migration must be serialized with `secret.store.lock` because a read can
become a write. Atomic replacement alone is not sufficient for detected
failures: retain the exact original bytes, verify the newly written v2
envelope, and restore the exact bytes if migration or verification fails.

Watch polling must not call `get()` unconditionally. Comparing the complete
envelope bytes, or a collision-resistant digest of those bytes, allows an
unchanged poll to skip JSON parsing, passphrase acquisition, scrypt, and
decryption. A changed envelope is decrypted once and becomes the next observed
snapshot only after successful validation.
