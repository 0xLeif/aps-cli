---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: research
---

# Research

- Separate `secret.key.lock` and `secret.store.lock` files do not serialize a
  set-side repair against get or watch in another process.
- Mutating an existing state root to `0700` can revoke intentional access to
  unrelated contents. A mode such as `0755` is safe for a `0600` key, while
  group or other write access permits pathname replacement and must fail closed.
- Canonicalizing the configured POSIX root once supports a symlinked root while
  retaining no-follow handling for the key leaf.
- A watch session may retain passphrase derivation state, but a cached key-file
  recipient must be discarded for every changed envelope snapshot.
- CLI get previously decrypted twice. CLI set previously performed a
  post-commit decrypt solely to render output, which could turn a successful
  write into a reported failure.
- Permission enforcement failures are security failures, not generic
  persistence failures.
