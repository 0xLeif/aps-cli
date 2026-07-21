---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: docs
---

# Docs

- README: root `--state-dir` before subcommand; `reset --all` vs `--registered`;
  secret SET must unlock; passphrase mode is stateful until first keyed write.
- `aps schema` command flags include `--registered`; `schemaVersion` bumps to 4.
- Specs `aps-cli` / `state-store` requirements updated via deltas in this change.
