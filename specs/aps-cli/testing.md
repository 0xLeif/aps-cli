# Testing -  APS CLI

- Unit: DemoKey metadata, parseBool, invalid set values
- Integration: StateStore round-trips via `@testable import aps`
- Unit: ObservedDependency stats mutation + Combine observation
- Smoke: `Scripts/smoke.sh` for flag/note persistence, reset, and `aps stats`

- SecureState `secret` round-trip / Keychain delete (Darwin) or keychainUnavailable (else).

- Slice `profileName` writes land in parent `profile` FileState.
