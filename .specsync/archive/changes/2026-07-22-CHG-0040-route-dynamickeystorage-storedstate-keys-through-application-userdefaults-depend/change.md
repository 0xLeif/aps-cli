---
id: CHG-0040-route-dynamickeystorage-storedstate-keys-through-application-userdefaults-depend
state: archived
type: bug_fix
base_commit: f76afad21becf7146c6edde94255c64bb29defe3
---

# Route DynamicKeyStorage StoredState keys through Application userDefaults dependency (issue 82)

## Intent

Route DynamicKeyStorage StoredState keys through Application userDefaults dependency (issue 82)

## Affected Canonical Specs

- None

## Acceptance Criteria

- DynamicKeyStorage StoredState operations use Application userDefaults dependency; tests overriding userDefaults cover dynamic StoredState keys.

## No-spec Rationale

Bug fix for test isolation and userDefaults injection
