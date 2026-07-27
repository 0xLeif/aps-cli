---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: testing
---

# Testing

## Unit coverage

- Secret reset throws on directory, symbolic-link, special-file, injected
  deletion, and injected postcondition failures.
- Secret reset removes an existing envelope, treats a missing envelope as
  success, and preserves the exact `secret.key` bytes and permissions.
- Concurrent secret set/reset operations serialize on `secret.store.lock` and
  end in one complete envelope or the verified missing state, never a torn
  envelope.
- FileState reset writes the encoded initial atomically under its per-file lock
  and preserves the previous file when encoding or replacement fails.
- Slice reset shares the parent FileState lock and preserves unrelated fields.
- Schema purge holds the schema lock through storage deletion, preventing a
  concurrent add from reusing the path.
- Injected purge failure restores the exact original schema document and
  retains the data.
- Injected purge plus rollback failure produces `rollback_failed`, leaves
  diagnostic state intact, and never reports success.
- Missing purge data is a successful no-op; wrong-kind data is rejected and
  preserved.
- Bulk reset in schema order reports `reset`, the first `failed` key and stable
  error, and `notAttempted`; stats equal the successful reset count only.

## CLI and smoke coverage

- Human reset and purge failures print no success line and exit nonzero.
- JSON reset and purge failures keep stdout empty and emit one stable error
  object on stderr.
- A partial bulk reset error includes all three result groups and exits with
  the underlying stable failure status.
- Unix and PowerShell smoke scripts cover successful FileState and
  EncryptedFile reset and purge plus deterministic wrong-kind failures.

## Cross-platform and gates

- Run `fledge lanes run verify`.
- Run SpecSync change verification and `fledge trust verify`.
- Require macOS, Linux, and Windows GitHub checks.
- Prefer injected I/O failures for deterministic behavior; retain native
  permission tests only where the platform can guarantee their preconditions.
