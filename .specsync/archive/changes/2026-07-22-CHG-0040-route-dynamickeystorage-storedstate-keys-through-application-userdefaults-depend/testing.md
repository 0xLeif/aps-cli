---
change: CHG-0040-route-dynamickeystorage-storedstate-keys-through-application-userdefaults-depend
artifact: testing
---

# Testing

## Verification Plan

- Unit test in `APSTests.swift` that overrides `Application.dependency(\.userDefaults)` and verifies user-defined StoredState keys get/set/reset through that dependency instead of `UserDefaults.standard`.
- Pass `fledge lanes run verify`.
