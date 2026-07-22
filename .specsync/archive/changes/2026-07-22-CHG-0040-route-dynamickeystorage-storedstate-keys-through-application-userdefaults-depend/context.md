---
change: CHG-0040-route-dynamickeystorage-storedstate-keys-through-application-userdefaults-depend
artifact: context
---

# Context

DynamicKeyStorage StoredState paths read and write `UserDefaults.standard` directly (`aps.user.<name>`), bypassing `Application.dependency(\.userDefaults)`. Test isolation and custom `userDefaults` overrides in AppState cannot cover dynamic StoredState keys until `DynamicKeyStorage` routes get, set, and reset through `Application.dependency(\.userDefaults)`.
