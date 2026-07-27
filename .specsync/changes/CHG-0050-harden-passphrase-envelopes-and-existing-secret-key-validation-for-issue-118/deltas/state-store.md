# state-store secure recipient persistence

## ADDED

### REQUIREMENT REQ-state-store-023

`SecretStore` SHALL preserve legacy v1 compatibility while making passphrase
migration, password derivation, key-file access, and encrypted watch polling
safe and deterministic across macOS, Linux, and Windows.

A successfully unlocked legacy passphrase envelope SHALL migrate under
`secret.store.lock` to strict v2 with a fresh salt. The migration SHALL retain
the exact original bytes, atomically replace and decrypt-verify v2, and restore
and verify the exact original after a detected failure. Legacy key-file
envelopes SHALL remain readable without a read-side rewrite and SHALL upgrade
on the next successful set.

Passphrase derivations MAY be cached only within one SecretStore operation and
only for the validated salt and fixed parameters. Encrypted watch SHALL compare
complete envelope snapshots before decryption and SHALL perform no KDF work for
an unchanged poll.

Key files SHALL be read, validated, repaired, and created through native open
handles. POSIX paths SHALL reject symbolic links and non-regular or
foreign-owned objects and SHALL require exact mode `0600`. Windows paths SHALL
reject reparse points, directories, non-disk objects, and foreign owners and
SHALL require the canonical protected private ACL. Only a proven owned regular
file MAY have its permissions or ACL repaired through its open handle. Creation
SHALL be exclusive and private before key bytes are written. Unsafe or
unrepairable existing paths SHALL remain unchanged.

Acceptance Criteria
- A correct legacy passphrase unlock produces verified v2 plaintext; a wrong
  passphrase does not attempt migration and preserves exact v1 bytes.
- Injected seal, write, reread, decode, decrypt-verification, and rollback
  failures never report migration success. A successful rollback restores
  byte-identical v1; failed rollback reports the stable rollback failure.
- A legacy key-file fixture reads without mutation and upgrades to strict v2
  only on the next successful set.
- One operation reuses a derivation for the same validated salt and discards
  the cache on return. A distinct new salt receives its own derivation.
- Initial encrypted watch decrypts once; any number of unchanged polls invoke
  scrypt zero additional times; changed data is strictly validated and
  decrypted before becoming the new baseline.
- POSIX opens use no-follow handles and verify regular type, effective-user
  ownership, and exact `0600`; safe repair and exclusive private creation are
  reverified through the handle.
- Windows opens reject reparse and wrong-kind handles, verify the current-user
  owner SID and private DACL, and reverify safe ACL repair and private
  `CREATE_NEW` creation.
- Symlink, reparse, directory, special-file, foreign-owner, invalid-key,
  failed-repair, and create-race tests prove no unsafe path is followed,
  truncated, replaced, or deleted.
- Existing-envelope invalid recipient material retains
  `secretUnlockFailed`; fresh persistence failures retain
  `persistenceFailed`; migration rollback failure retains the stable rollback
  contract.
- Unit, subprocess, smoke, concurrency, SpecSync, Trust, provenance, macOS,
  Ubuntu, Linux smoke, and Windows checks pass.
