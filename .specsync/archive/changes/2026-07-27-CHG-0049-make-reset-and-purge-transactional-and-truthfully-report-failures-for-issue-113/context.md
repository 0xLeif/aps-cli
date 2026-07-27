---
change: CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113
artifact: context
---

# Context

Reset and purge currently contain best-effort deletion paths. `SecretStore.reset`
and older adapter paths discard errors, while FileState reset deletes the old
file before attempting to write its initial value. A command can therefore
print success even though data remains, or destroy the old value and then fail
to establish the reset value.

`key remove --purge` commits the schema removal under `schema.json.lock`, drops
that lock, and deletes storage afterward. A concurrent schema mutation can
reuse the same path between those operations. If deletion then fails, the key
is no longer registered even though its data remains.

Bulk reset stops by thrown error today but has no explicit contract describing
which keys succeeded or were not attempted. Mutation statistics must not count
failed attempts.

Issue #113 makes detected failures truthful and defines one lock and rollback
protocol. It does not claim atomicity across process termination, power loss, or
filesystem failure modes that occur after an operation reports success.
