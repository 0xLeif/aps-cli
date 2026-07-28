---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: requirements
---

# Requirements

1. Every newly written encrypted envelope shall use strict version 2 and record
   exactly one recipient mode: `passphrase` or `keyFile`.
2. A v2 passphrase envelope shall record scrypt with a fresh cryptographically
   random 16-byte salt, `N=131072`, `r=8`, `p=1`, and 32 output bytes. APS
   shall validate every value exactly before invoking the KDF.
3. A v2 key-file envelope shall omit password-KDF metadata. APS shall not fall
   back between v2 recipient modes or create key material for the wrong mode.
4. Envelope base64 and cryptographic field lengths shall be validated before
   key agreement or decryption. Unsupported versions, malformed mode/KDF
   combinations, duplicate or unknown JSON keys, and unsupported KDF parameters
   shall fail as decoding errors without attacker-selected KDF work.
5. Legacy unversioned key-file envelopes shall remain readable without a
   read-side rewrite and shall upgrade to v2 on the next successful set.
6. A legacy unversioned passphrase envelope shall migrate to v2 only after
   successful legacy unlock. Migration shall hold `secret.store.lock`, preserve
   the exact original bytes, atomically write and verify v2, and restore and
   verify the exact original on detected failure.
7. Wrong legacy credentials shall not attempt migration. Wrong credentials and
   successfully rolled-back migration failures shall leave the original
   envelope byte-identical and shall never report success.
8. Passphrase derivation may be memoized only within one SecretStore operation,
   keyed by the validated salt and fixed parameters. No raw passphrase or
   derived key shall enter a process-wide or persistent cache.
9. Encrypted watch shall compare complete envelope snapshots before decryption.
   Any unchanged poll shall perform no passphrase KDF. Changed data shall be
   strictly validated and decrypted before becoming the next baseline.
10. POSIX key-file access shall use no-follow native handles. The opened object
    shall be a regular file owned by the effective user and have exact mode
    `0600`; a safely owned regular file may be repaired through its handle and
    must then be reverified.
11. Windows key-file access shall use native handles that reject reparse points,
    directories, and non-disk objects. The owner SID shall match the current
    process user and the DACL shall match the canonical protected private ACL;
    a safely owned regular file may be repaired through its handle and must
    then be reverified.
12. New key files shall use exclusive creation with private permissions or a
    private security descriptor established before key bytes are written.
    Reading, validating, repairing, and creating shall not follow or truncate
    an existing unsafe path.
13. Foreign-owned, wrong-kind, reparse, invalid, and unrepairable key paths
    shall be rejected without replacement or deletion. Existing-envelope
    failures shall retain stable unlock error mapping; fresh persistence
    failures shall retain stable persistence error mapping.
14. The implementation shall use the public CryptoExtras scrypt API from
    apple/swift-crypto `4.0.0..<4.4.0`, work on macOS, Linux, and Windows, and
    contain no production force try or force cast.
15. Tests shall prove strict parsing, bounded KDF invocation, legacy
    compatibility and rollback, safe handle behavior, private creation,
    unchanged-watch cost, stable errors, and successful tri-OS verification.
