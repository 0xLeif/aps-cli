---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: requirements
---

# Requirements

1. Every repair-capable key-file load for get, set, or watch shall serialize
   through `secret.store.lock`.
2. On POSIX, SecretStore shall canonicalize the configured state root once.
   It shall preserve safe owned directory modes such as `0755` and reject
   group- or other-writable roots without changing them.
3. Permission-repair failures shall map to
   `APSError.insecureSecretKeyFile`, while unrelated I/O failures retain their
   persistence mapping.
4. Key-file watch mode shall reload and revalidate the key for every changed
   envelope snapshot. Unchanged polls shall perform no recipient work.
5. CLI get shall perform one encrypted read. After a verified encrypted set,
   CLI output shall use the verified submitted value without another decrypt.
6. The canonical contract shall retain the actual v2 KDF wire names and
   distinguish unsupported envelopes from malformed envelopes.
7. A successful string-name StateStore set shall return the exact schema entry
   resolved while the schema lock is held.
