---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-031 | Store-lock, POSIX-root, permission-error, changed-watch, StateStore entry-return, and full CLI smoke regressions in `APSTests`, `SecureKeyFileTests`, and `SecretStoreSecurityTests` |
| REQ-state-store-024 | `APSTests.testRegistrySetReturnsExactResolvedEntry` verifies the returned entry is the one resolved under lock |

- Prove get recreates `secret.store.lock` and never creates
  `secret.key.lock`.
- Prove a `0755` owned root is preserved, a `0775` root is rejected unchanged,
  and a symlinked root round-trips through its canonical target.
- Prove Darwin mode `0000` fails with `insecure_secret_key_file` and preserves
  the key.
- Prove changed watch snapshots accept coherent key/envelope rotation and
  revalidate permissive key permissions.
- Preserve the existing one-prompt passphrase watch and unchanged-poll KDF
  counts.
- Prove StateStore set returns the exact entry resolved under the schema lock.
- Run `fledge lanes run verify`: 234 serial tests, 234 parallel tests, smoke,
  CI dogfood, installer contract, and plugin validation.
- Require macOS/Ubuntu CI, Linux smoke, Windows smoke, and Trust checks.
