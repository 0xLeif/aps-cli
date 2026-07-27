---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: testing
---

# Testing

## Envelope and cryptography

- Assert every new passphrase envelope is version 2, records
  `recipientMode=passphrase`, contains a unique 16-byte random salt, and records
  exactly scrypt `N=131072`, `r=8`, `p=1`, output 32.
- Assert two writes of the same plaintext and passphrase produce different
  salts and ciphertext while both round-trip.
- Assert new key-file envelopes record `recipientMode=keyFile` and omit `kdf`.
- Reject unsupported version, unknown mode or KDF, missing or extra
  mode-dependent KDF data, malformed base64, wrong decoded field lengths, and
  duplicate or unknown JSON keys. Reject every KDF parameter one below or above
  the supported constant before the KDF test seam records an invocation.
- Verify wrong passphrase, wrong key, and v2 mode mismatch return the stable
  error and leave envelope and key-file bytes unchanged.

## Compatibility and migration

- Open an exact legacy v1 key-file fixture on macOS, Linux, and Windows without
  changing it; verify the next successful set writes strict v2 key-file data.
- Open an exact legacy v1 passphrase fixture with the old HKDF derivation,
  migrate under the store lock, and verify the same plaintext from strict v2.
- Verify a wrong legacy passphrase does not attempt migration and preserves
  exact bytes.
- Inject failure at v2 seal, atomic write, reread, strict decode, decrypt
  verification, rollback write, and rollback verification. Successful rollback
  must restore exact v1 bytes and return failure. Failed rollback must return
  the stable rollback failure and never report the plaintext operation as
  successful.
- Race migration with set and reset subprocesses and prove
  `secret.store.lock` permits only complete legacy, complete v2, or verified
  absence states, never a torn envelope.

## KDF cost behavior

- Inject a counting KDF. One v2 get derives once for one salt.
  Unlock-before-rewrite and read-back reuse each salt within the operation.
- A bounded encrypted watch derives for the initial snapshot and zero times for
  any number of unchanged polls.
- A changed envelope causes one validation and derivation for its salt. Corrupt
  or attacker-selected parameters fail before derivation.
- Operation completion discards the cache; a later command derives again.

## Key-file validation

- POSIX tests cover an owned regular `0600` file, safe repair from permissive or
  incomplete owner mode to exact `0600`, symbolic links, directories, FIFOs,
  foreign-owner injection, failed `fchmod`, identity-change injection, invalid
  base64, invalid X25519 bytes, and exclusive-create races.
- Windows tests cover a private owned regular file, safe DACL repair, reparse
  points, directories, non-disk handles, foreign-owner injection, inherited or
  unexpected access entries, failed ACL repair, invalid key bytes, and
  `CREATE_NEW` races.
- Unsafe or failed validation preserves exact contents and does not truncate,
  replace, follow, or delete the path. Fresh recovery only replaces invalid
  material after the same safe-handle proof required by the existing contract.
- New files are private at creation, then reread and revalidated through their
  handles. POSIX asserts exact `0600`; Windows asserts the canonical protected
  owner-only ACL.

## CLI, smoke, and gates

- Unix and PowerShell smoke cover v2 passphrase and key-file round trips,
  legacy compatibility, wrong credentials, reset, and unchanged encrypted
  watch.
- Production-source scans reject `try!` and `as!`; normal Swift style and
  concurrency checks remain active.
- Run `fledge lanes run verify`, strict SpecSync verification,
  `fledge trust verify`, and provenance verification.
- Require macOS, Ubuntu, Linux smoke, Windows smoke, and Trust GitHub checks.
