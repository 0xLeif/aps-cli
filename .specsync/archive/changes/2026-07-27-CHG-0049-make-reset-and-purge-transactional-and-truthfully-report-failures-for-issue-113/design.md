---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: design
---

# Design

## Transaction boundary

The contract is detected-error transactional, not crash atomic. If an operation
returns success, its postcondition was observed. If a filesystem or encoding
error is detected before return, the operation reports failure and performs the
defined rollback. The design does not promise recovery when the process is
killed, the machine loses power, or a hostile process races filesystem changes
outside APS locks.

## Lock ordering

All code follows one global order:

1. acquire `schema.json.lock` when the registry is being changed;
2. acquire the target storage lock while still holding the schema lock;
3. perform and verify the storage operation;
4. release the storage lock;
5. release the schema lock.

Code that only resets a registered value acquires its storage lock and does not
take the schema lock. No code may acquire the schema lock while holding a
storage lock. FileState uses the canonical per-file lock. EncryptedFile uses
`secret.store.lock`. The dedicated `secret.key.lock` is not part of reset
because reset never changes key material.

## Schema removal with purge

`removeKey(name:purge:)` performs one schema-lock transaction:

1. load and retain the original validated schema;
2. resolve the entry and dependency constraints;
3. build and write the candidate schema without the entry;
4. while still holding the schema lock, acquire the storage lock and purge;
5. verify the purge postcondition;
6. return only after both schema and storage postconditions hold.

If purge detects an error, APS writes the retained original schema back before
releasing the schema lock. A successful rollback rethrows the original stable
purge error. If restoring the schema also fails, APS throws a distinct stable
rollback error that identifies `schema.json` and preserves the purge failure as
diagnostic context. The schema lock prevents another APS process from claiming
the removed path during the candidate-schema interval.

Deletion is a verified regular-leaf unlink. Missing data is a successful no-op.
Directories, symbolic links, special files, and failed postcondition checks
remain unchanged and fail. The storage adapters are structured so a detected
delete failure occurs before mutation; after a successful unlink, absence is
the only success state.

## Reset adapters

FileState reset encodes the entry initial first, then acquires the same per-file
lock used by set and Slice writes. It resolves the safe path, atomically writes
the replacement, reads it back through the entry type, and returns only if the
initial value is observed. The old file is never explicitly deleted before the
replacement. A missing initial follows the verified leaf-deletion contract.

EncryptedFile reset calls a throwing SecretStore envelope-reset method.
SecretStore validates the configured path, acquires `secret.store.lock`,
removes only the envelope regular leaf, and checks that the envelope is absent.
It never deletes, truncates, regenerates, or locks `secret.key`, because that
key material is shared by other encrypted entries and future writes.

State reset mutates process memory directly. StoredState reset removes and
replaces the canonical value, synchronizes where supported, and verifies the
observable value. Slice reset uses the parent FileState lock and atomic parent
rewrite. Every adapter records stats only after verification succeeds.

## Stable failures and bulk reporting

Expected failures use stable domain codes and exit statuses rather than raw OS
messages. Unsafe or wrong-kind schema paths remain `schema_invalid` with exit
65. Persistence, deletion, and postcondition failures use
`persistence_failed` with exit 73. Failure to restore the original schema uses
a new stable `rollback_failed` error with an I/O failure exit and a fixed hint
to inspect `schema.json` and the retained data. Secret unlock and decoding
failures retain their existing codes.

Bulk reset iterates the selected schema entries in document order and stops at
the first failure. A `BulkResetReport` contains:

- `reset`: keys whose reset postcondition succeeded;
- `failed`: the first failed key plus stable code and message, or null;
- `notAttempted`: remaining selected keys.

The thrown bulk failure carries this report and its underlying domain error.
Machine mode emits one structured error containing the report on stderr and
keeps stdout empty. Human mode prints the failed key and the two key lists.
Successful keys keep their mutations and stats; bulk reset does not attempt to
roll them back. This is explicit fail-fast reporting, not all-keys atomicity.
