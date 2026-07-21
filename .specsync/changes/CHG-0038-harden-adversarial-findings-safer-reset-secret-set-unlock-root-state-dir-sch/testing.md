---
change: CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-011 | `testPeelRootStateDirBeforeSubcommand`; smoke `aps --state-dir OTHER get note` |
| REQ-aps-cli-019 | smoke/schemaVersion 4; `testSchemaDocumentCoversAllKeysAndCommands` |
| REQ-aps-cli-020 | `testSecretSetRequiresUnlockBeforeRewrite`; smoke wrong-passphrase SET |
| REQ-aps-cli-023 | `testResetAllLeavesUserKeysResetRegisteredClearsThem`; smoke seed vs registered |
| REQ-aps-cli-024 | smoke greps `schemaVersion` 4 and `--registered`; schema unit test |
| REQ-state-store-016 | `testUserSchemaMaterializeAndKeyAdd`; registry get/set/reset; resetAll scope test |
| REQ-state-store-017 | `testParallelSchemaAddsUnderLockRetainAllKeys`; smoke parallel `key add` |
| REQ-state-store-018 | `testSecretSetRequiresUnlockBeforeRewrite` |

## Suites

- `./Scripts/test.sh` (61 tests)
- `./Scripts/smoke.sh` and `Scripts/smoke.ps1`
- `fledge lanes run verify`
