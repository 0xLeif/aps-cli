---
change: CHG-0065-add-runnable-agent-ci-swift-integration-and-release-pipeline-examples-with-re
artifact: testing
---

# Testing

- `Scripts/test-examples.sh` runs both shell examples against isolated roots,
  compiles and runs the Swift harness, and checks the GitHub Actions contract.
- The example contract is part of `fledge lanes run verify`.
- `specsync change verify ... --strict` runs the complete project gate before
  acceptance.
