---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: requirements
---

# Requirements

1. Every reset and purge adapter shall propagate a stable domain error when a
   detected persistence operation fails. No success payload or success text
   shall be emitted after such a failure.
2. A FileState reset with an initial value shall encode and atomically overwrite
   the target under its per-file lock. It shall not delete the current file
   before the replacement is ready.
3. EncryptedFile reset shall use a throwing SecretStore operation that holds the
   store lock, removes only the verified envelope leaf, verifies that the
   envelope is absent, and preserves shared `secret.key` material.
4. Schema removal with purge shall hold `schema.json.lock` for the complete
   operation and acquire any storage lock only after the schema lock.
5. Purge shall write the candidate schema, attempt storage deletion, and restore
   the original schema on any detected purge failure. A rollback-write failure
   shall be reported distinctly from an ordinary purge failure.
6. The transaction guarantee is limited to errors detected before the API
   returns. It shall not claim crash, power-loss, or distributed-filesystem
   atomicity.
7. Bulk reset shall be deterministic and fail fast in schema order. Its result
   shall identify successfully reset keys, the first failed key and stable
   error, and all keys not attempted.
8. Mutation statistics shall be recorded only after each reset reaches its
   verified success postcondition.
9. Wrong-kind paths, deletion failures, rollback failures, concurrent path
   reuse, and secret set/reset races shall produce deterministic cross-platform
   behavior on macOS, Linux, and Windows.
