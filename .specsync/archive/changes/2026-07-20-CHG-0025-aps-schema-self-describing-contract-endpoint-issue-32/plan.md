---
change: CHG-0025-aps-schema-self-describing-contract-endpoint-issue-32
artifact: plan
---

# Plan

1. Add `Schema.swift` (document model + minimal JSON Schema node encoder).
2. Wire `SchemaCmd` into the command tree.
3. Tests: key/command coverage, error table stability, encoded validity.
4. Smoke: schemaVersion, key entries, error code, cliVersion equals
   `--version`.
5. aps-cli spec (files list + informational command tree), requirements
   (REQ-aps-cli-016), README agent section.
