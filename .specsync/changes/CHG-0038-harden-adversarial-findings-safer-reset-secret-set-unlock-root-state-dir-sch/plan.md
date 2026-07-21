---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: plan
---

# Plan

1. Peel leading root `--state-dir` before ArgumentParser; subcommand flag still wins.
2. Make `reset --all` seed-only; add `reset --registered` for full wipe.
3. Require `SecretStore.set` to unlock an existing envelope before rewrite.
4. Hold an exclusive lock around schema.json RMW (add/remove) with re-read under lock.
5. Update README, `aps schema` flags/`schemaVersion`, smoke, and unit tests; verify.
