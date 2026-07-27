---
change: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
artifact: tasks
---

# Tasks

- [ ] Pin swift-crypto to `4.0.0..<4.4.0` and link the public CryptoExtras
  product.
- [ ] Implement the fixed-parameter scrypt abstraction and secure 16-byte salt
  generation.
- [ ] Add strict v2 envelope decoding, recipient-mode dispatch, and bounded
  field and parameter validation.
- [ ] Preserve legacy v1 key-file reads and upgrade them on the next successful
  write.
- [ ] Implement locked transactional legacy passphrase migration with exact
  rollback and postcondition verification.
- [ ] Add operation-scoped KDF caching and prove read-back does not duplicate a
  derivation for the same envelope salt.
- [ ] Make encrypted watch skip KDF and decryption for unchanged envelope
  snapshots.
- [ ] Implement POSIX no-follow handle validation, exact `0600` repair, and
  exclusive private creation.
- [ ] Implement Windows reparse rejection, handle ownership and DACL
  validation, safe ACL repair, and exclusive private creation.
- [ ] Remove production force try and force cast usage covered by the audit.
- [ ] Add malformed-envelope, excessive-parameter, wrong-mode, wrong-password,
  migration rollback, key-file adversarial, KDF-count, and tri-OS tests.
- [ ] Update README, security documentation, dynamic-schema documentation,
  dependency records, CLI schema contract, and canonical specs.
- [ ] Pass local verify, strict SpecSync, Trust, provenance, and macOS, Ubuntu,
  Linux smoke, and Windows hosted checks.

No security acceptance item is complete until its implementation and regression
evidence are present. Permission and ACL tests must use deterministic injected
seams where platform or CI privileges make ambient filesystem behavior
unreliable.
