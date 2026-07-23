---
change: CHG-0042-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: plan
---

# Plan

1. Recover invalid `secret.key` only when no `secret.enc` envelope exists.
2. Add regression coverage and align the canonical SecretStore contract.
3. Verify with fledge and strict SpecSync, then accept the successor change.
