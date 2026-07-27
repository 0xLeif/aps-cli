---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: design
---

# Design

## Envelope contract

All new writes encode a v2 JSON object with:

- `version`: integer `2`;
- `recipientMode`: exactly `passphrase` or `keyFile`;
- `ephemeralPublicKey`, `nonce`, `ciphertext`, and `tag`: the existing base64
  ChaCha20-Poly1305 payload fields;
- `kdf`: present only for `passphrase`, containing `name: "scrypt"`,
  `salt`, `n: 131072`, `r: 8`, `p: 1`, and `outputByteCount: 32`.

The salt decodes to exactly 16 bytes, the ephemeral public key to 32 bytes, the
nonce to 12 bytes, and the tag to 16 bytes. Base64 must decode successfully.
The top-level object and nested KDF object contain only their documented keys;
duplicate and unknown keys are rejected.
The version, mode, KDF name, and every numeric parameter must equal the
supported constants before scrypt runs. A key-file envelope must not contain a
KDF descriptor. A passphrase envelope must contain one. Unsupported versions,
mode/KDF combinations, parameter values, and malformed fields fail as
`APSError.decodingFailed`; they never select a fallback mode or a disk-provided
work factor.

Each passphrase seal obtains 16 bytes from the platform cryptographic random
generator and derives a 32-byte X25519 private key with scrypt
`N=131072, r=8, p=1`. New key-file envelopes record `keyFile` but preserve the
existing X25519, HKDF, and ChaCha20-Poly1305 construction. The v2 metadata is a
strict dispatch contract. Successful authenticated decryption proves the
selected recipient and payload agree.

## Version and compatibility behavior

An object with exactly the four legacy payload fields and no `version` is v1.
Unknown partial-version shapes are not treated as legacy.

- v1 plus active key-file mode remains readable without changing bytes.
  A later successful `set` first proves v1 unlock and writes v2 `keyFile`.
- v1 plus active passphrase mode first unlocks with the legacy HKDF rule. A
  successful `get` then migrates it to v2 `passphrase`.
- v2 uses only its recorded mode. `passphrase` requires a nonempty configured
  or prompted passphrase. `keyFile` uses the validated key-file path and does
  not fall back to a passphrase.
- Wrong credentials are `secretUnlockFailed`. They never cause migration,
  mode fallback, key creation, key replacement, or envelope mutation.

Passphrase migration acquires `secret.store.lock`, reads and retains the exact
v1 bytes, opens those bytes, creates a fresh v2 salt and envelope for the same
plaintext, atomically replaces the file, rereads it, strictly validates it,
and decrypts it with the operation context. Success is returned only after the
same plaintext is observed. If any migration step fails, the exact v1 bytes
are restored and verified before the error is returned. A successful rollback
reports the original persistence failure. A failed rollback reports the stable
rollback failure with the migration failure retained as diagnostic context.
Wrong credentials and any successfully rolled-back migration failure leave the
v1 bytes byte-identical.

## Operation-scoped derivation

A SecretStore operation creates a short-lived recipient context. It holds the
selected mode and may memoize a derived passphrase X25519 key by the validated
salt and fixed KDF constants. `get`, unlock-before-rewrite `set`, read-back
verification, and migration reuse that context instead of rerunning scrypt for
the same salt. A rewrite with a new salt performs one additional derivation for
that salt. The context is discarded when the operation returns and is never
global, static, persisted, or shared between commands. Raw passphrases are not
placed in a process-wide cache.

Encrypted watch retains the exact last envelope bytes or their
collision-resistant digest. The initial read decrypts once. Each poll reads
the envelope snapshot but skips decoding and KDF work when the bytes are
unchanged. A distinct snapshot is strictly decoded and decrypted once; only a
successful value becomes the new watch baseline. Corrupt or unauthenticated
changed bytes surface the existing stable error.

## Secure key-file access

Key-file reads and creation are implemented behind a platform-neutral
`SecureKeyFile` API that returns data from an already validated native handle.
Validation occurs while `secret.key.lock` or the containing store transaction
is held when mutation or repair may occur.

On POSIX, opening uses `O_RDONLY | O_NOFOLLOW | O_CLOEXEC`; creation uses
`O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC` with `0600`. Permission repair
moves an unreadable file to a random quarantine name and pins its identity to a
native descriptor before chmod. Linux uses `O_PATH` plus `/proc/self/fd`;
Darwin uses an `O_WRONLY | O_NOFOLLOW` descriptor. Darwin mode `0000` cannot
produce a safe descriptor and fails closed after restoring the exact entry;
mode `0200` repairs to `0600`. Any repair failure restores the quarantine
before returning. A symlink, foreign owner, non-regular object, failed repair,
changed identity, or invalid key is rejected.

On Windows, opening and exclusive creation use `CreateFileW` and
`FILE_FLAG_OPEN_REPARSE_POINT`. Handle metadata must prove a non-directory disk
file without `FILE_ATTRIBUTE_REPARSE_POINT`. The security descriptor owner SID
must equal the current process user SID. The DACL must grant access only to
that owner and required system identity, without access-granting inherited or
unrecognized entries. A safely owned regular file with a permissive DACL is
repaired through the handle to the canonical protected owner-only ACL and
reverified. Reparse, foreign-owned, wrong-kind, invalid, and unrepairable paths
are rejected without replacement or truncation. New files receive the private
security descriptor at `CREATE_NEW`, before key bytes are written.

## Failure and dependency boundaries

The implementation uses the public `CryptoExtras` scrypt surface from
apple/swift-crypto `4.0.0..<4.4.0`. No private SPI, force try, force cast, or
force unwrap is allowed in production. KDF and platform failures map to stable
APS errors without including passphrases, derived keys, salts beyond the public
envelope, raw ACLs, or key bytes in user-facing messages.

Permission repair is the only allowed mutation of a safely owned existing key
file during validation. Unsafe or failed validation leaves the path and its
contents unchanged. Envelope writes retain the existing store lock, atomic
replacement, and read-back discipline.
