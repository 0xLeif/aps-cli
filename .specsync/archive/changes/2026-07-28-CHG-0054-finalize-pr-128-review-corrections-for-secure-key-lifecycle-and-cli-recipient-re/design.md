---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: design
---

# Design

SecretStore canonicalizes its POSIX directory in every initializer. Secure key
access validates that the canonical parent is an owned directory without group
or other write access, but never changes the parent mode.

`secret.store.lock` is the single cross-process lock for key loading, repair,
and creation. Set already holds it through its transaction and uses the
unlocked helper. Get and watch acquire it around their repair-capable load.

Encrypted watch clears only the cached key-file recipient before decrypting a
changed snapshot. Passphrase, legacy, and scrypt caches remain operation
scoped and unchanged.

StateStore set returns the schema entry resolved under its lock. CLI set uses
the submitted raw value for EncryptedFile output after SecretStore has
decrypt-verified persistence; other storage types retain their canonicalizing
read-back. CLI get relies on its single value snapshot.

SecureKeyFile uses a distinct permission-repair error carrying operation and
platform code. SecretStore maps that case to the stable insecure-key-file
contract.
