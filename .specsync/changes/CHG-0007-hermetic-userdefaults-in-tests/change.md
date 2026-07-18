---
id: CHG-0007-hermetic-userdefaults-in-tests
state: accepted
type: refactor
base_commit: 50eddbbb5c6bf829995523f0a9cd8f75f82f7cc6
---

# Hermetic UserDefaults in tests

## Intent

Hermetic UserDefaults in tests

## Affected Canonical Specs

- None

## Acceptance Criteria

- Test runs leave zero keys in the standard domain, and flag round-trip and persistence tests still pass against the injected suite.

## No-spec Rationale

Only isolates UserDefaults in tests; no canonical specification changes.
