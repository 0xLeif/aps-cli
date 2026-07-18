# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-016 | `testProfileNameSliceWritesLandInParent`, `testProfileNameSliceReadsParentField`, `testDemoKeyMetadata` |
| REQ-state-store-014 | `testProfileNameSliceWritesLandInParent`, `readProfileFromDisk` assertion |

## Suites

- `swift test`
- `fledge lanes run verify`
