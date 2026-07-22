---
change: CHG-0040-route-dynamickeystorage-storedstate-keys-through-application-userdefaults-depend
artifact: tasks
---

# Tasks

- [x] Update `DynamicKeyStorage.swift` and `StateStore+Registry.swift` to use `Application.dependency(\.userDefaults).value` for StoredState operations
- [x] Add unit test covering user-defined StoredState key with overridden `userDefaults` dependency
