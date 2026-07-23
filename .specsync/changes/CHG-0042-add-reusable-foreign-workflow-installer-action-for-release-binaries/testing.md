---
change: CHG-0042-add-reusable-foreign-workflow-installer-action-for-release-binaries
artifact: testing
---

# Testing

`.github/actions/install-aps/test.sh` checks the composite metadata, supported asset mapping, HTTPS curl retry flags, digest verification, temporary-file promotion, and GitHub environment-file updates. `specsync check` validates repository contracts, and `fledge lanes run verify` runs the build, Swift tests, and smoke checks.
