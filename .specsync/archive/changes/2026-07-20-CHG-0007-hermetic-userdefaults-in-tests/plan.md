---
change: CHG-0007-hermetic-userdefaults-in-tests
artifact: plan
---

# Plan

1. Inject a custom `UserDefaults` suite domain using `Application.override(\.userDefaults)` in `setUp`.
2. Clear the persistent suite domain using `removePersistentDomain(forName:)` in `tearDown`.
3. Cancel the override token returned by `Application.override` in `tearDown`.
