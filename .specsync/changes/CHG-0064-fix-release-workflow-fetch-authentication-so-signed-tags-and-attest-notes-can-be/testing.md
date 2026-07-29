---
change: CHG-0064-fix-release-workflow-fetch-authentication-so-signed-tags-and-attest-notes-can-be
artifact: testing
---

# Testing

- `Scripts/test-release-distribution.sh` asserts both release checkouts persist
  their job credential and rejects manual Authorization-header construction.
- `fledge lanes run verify` exercises the release distribution contract.
- A `workflow_dispatch` run for `v1.1.0` proves tag, default-branch, and attest
  note fetches succeed on the GitHub-hosted runner.
