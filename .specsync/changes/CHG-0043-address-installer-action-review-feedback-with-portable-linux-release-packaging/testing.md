---
change: CHG-0043-address-installer-action-review-feedback-with-portable-linux-release-packaging
artifact: testing
---

# Testing

The Action test validates the portable asset mapping, archive extraction contract, release rpath packaging, fledge wiring, and valid/invalid SemVer examples. `bash -n`, strict `specsync check`, strict `specsync change check`, and `fledge lanes run verify` are required before acceptance.
