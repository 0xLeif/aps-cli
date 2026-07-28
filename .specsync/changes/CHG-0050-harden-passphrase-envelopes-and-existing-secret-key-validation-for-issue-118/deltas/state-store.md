# state-store secure recipient persistence

## ADDED

### REQUIREMENT REQ-state-store-023

`SecretStore` SHALL preserve unversioned legacy compatibility while making
passphrase migration, password derivation, key-file access, and encrypted-watch
polling safe and deterministic across macOS, Linux, and Windows.

A successfully unlocked legacy passphrase envelope SHALL migrate under
`secret.store.lock` to strict v2 with a fresh salt. Migration SHALL retain the
exact original bytes, atomically replace and decrypt-verify v2, and restore and
verify the exact original after a detected failure. A wrong passphrase SHALL
not attempt migration. Legacy key-file envelopes SHALL remain readable without
a read-side rewrite and SHALL upgrade only on the next successful set.

Passphrase derivations MAY be cached only within one SecretStore operation and
only for a validated salt and the fixed `N=131072`, `r=8`, `p=1`, 32-byte
profile. The cache SHALL be discarded when the operation returns. Encrypted
watch SHALL compare complete envelope byte snapshots before decryption and
SHALL perform no KDF work for an unchanged poll. Changed bytes SHALL be
strictly validated and decrypted before becoming the next watch baseline.

Key files SHALL be read, repaired, and created through validated native open
handles. POSIX paths SHALL reject symbolic links and non-regular or
foreign-owned objects and SHALL require exact mode `0600`. Windows paths SHALL
reject reparse points, directories, non-disk objects, and foreign owners and
SHALL require the canonical protected private DACL for the current user. Only
a proven safely owned regular file MAY have its permissions or ACL repaired
through its handle. Creation SHALL be exclusive and private before key bytes
are written. Unsafe or unrepairable existing paths SHALL remain unchanged.

Acceptance Criteria
- Correct legacy passphrase unlock returns the original plaintext only after
  verified v2 migration; a wrong passphrase preserves exact v1 bytes.
- Injected seal, write, reread, decode, decrypt-verification, and rollback
  failures never report migration success. Successful rollback restores exact
  v1 bytes; failed rollback returns `rollback_failed`.
- A legacy key-file fixture reads without mutation and upgrades to strict v2
  only on the next successful set.
- One operation reuses a derivation for the same validated salt, derives once
  for each distinct new salt, and discards its cache on return.
- Initial encrypted watch decrypts once. Any number of unchanged polls invoke
  scrypt zero additional times; changed bytes validate and decrypt once.
- POSIX handles prove regular type, effective-user ownership, and exact `0600`.
  Safe repair and exclusive private creation are reverified through the handle.
- Windows handles reject reparse and wrong-kind objects, verify current-user
  ownership and the private DACL, and reverify safe ACL repair and private
  `CREATE_NEW` creation.
- Symlink, reparse, directory, special-file, foreign-owner, invalid-key,
  failed-repair, and create-race cases never follow, truncate, replace, or
  delete an unsafe existing path.
- Existing-envelope invalid recipient material retains
  `secret_unlock_failed`; fresh persistence failures retain
  `persistence_failed`; unsafe handles use `insecure_secret_key_file`; and
  migration restoration failure retains `rollback_failed`.
