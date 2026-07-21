---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: context
---

# Context

Adversarial dogfood (multi-writer, passphrase probes, parallel `key add`) found four
breakages that block safe CI / agent use of a shared state root:

1. `#85` `aps reset --all` wipes every registered key, including agent FileState keys.
2. `#87` Root `aps --state-dir PATH <cmd>` is rejected though help advertises the flag.
3. `#89` / `#88` `SecretStore.set` re-keys without proving the current unlock; GET enforces.
4. `#90` Parallel `key add` RMW on `schema.json` can drop peer updates (last-writer-wins).

This change hardens those paths in one delivery so dogfood roots stay recoverable.
