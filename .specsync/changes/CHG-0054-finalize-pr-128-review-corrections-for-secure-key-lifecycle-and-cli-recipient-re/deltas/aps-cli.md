# aps-cli final secret lifecycle review corrections

## ADDED

### REQUIREMENT REQ-aps-cli-031

Every key-file load that may repair or create key material SHALL serialize
through `secret.store.lock`, including get, set, and changed watch snapshots.
Key-file watch SHALL reload and revalidate the key for every changed envelope;
unchanged polls SHALL perform no recipient work.

On POSIX, SecretStore SHALL canonicalize the configured state root once,
preserve safe owned directory modes such as `0755`, and reject group- or
other-writable roots without changing their permissions. Permission-repair
failures SHALL return `insecure_secret_key_file`; unrelated I/O failures retain
their persistence mapping.

CLI get SHALL perform one encrypted read. After SecretStore successfully
persists and decrypt-verifies an encrypted set, CLI output SHALL use the
verified submitted value without another decrypt.

The v2 KDF wire keys remain `algorithm`, `salt`, `rounds`, `blockSize`,
`parallelism`, and `outputByteCount`. Unsupported versions or recipient modes
SHALL return `unsupported_secret_envelope`; malformed fields and KDF
combinations SHALL return `decoding_failed`. Invalid existing key material
SHALL never be truncated, replaced, or deleted.

Acceptance Criteria
- Get, set, and watch use one store lock for repair-capable key access.
- Safe POSIX root modes are preserved; writable roots fail closed unchanged;
  symlinked roots round-trip through one canonical target.
- Changed key-file watch snapshots support coherent key/envelope rotation and
  revalidate key privacy.
- CLI get performs one decrypt and encrypted set output performs no
  post-commit decrypt.
- The full 234-test local lane and every hosted platform gate pass.
