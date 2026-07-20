---
change: CHG-0007-hermetic-userdefaults-in-tests
artifact: testing
---

# Testing

Verify correctness by adding `testUserDefaultsStandardIsHermetic()` which asserts that no `aps.flag` keys are created in the standard `UserDefaults` domain during test execution. Run all 28 unit tests.
