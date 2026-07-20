---
change: CHG-0007-hermetic-userdefaults-in-tests
artifact: context
---

# Context

Tests currently write `aps.flag` into the real `UserDefaults.standard` domain. To prevent test suite execution from side-effecting standard user defaults, we isolate the tests using an injected `UserDefaults` suite per run.
