---
change: CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-034 | `DynamicObjectTypingTests` numeric and nonfinite cases plus `APSTests.testSchemaDocumentEncodesValidContractJSON` |
| REQ-state-store-027 | `APSTests` absent, canonical-corrupt, and legacy-corrupt StoredState cases plus recursive nonfinite tests |

- Regression safety uses `fledge lanes run verify`, `fledge spec check --strict`,
  and hosted CI, Linux, Windows, and Trust.
