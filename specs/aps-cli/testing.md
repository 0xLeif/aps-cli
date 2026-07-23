# Testing -  APS CLI

- Unit: DemoKey metadata, parseBool, invalid set values
- Integration: StateStore round-trips via `@testable import aps`
- Unit: ObservedDependency stats mutation + Combine observation
- Isolation: each `APSTests` case scopes a temp FileState path, hermetic
  in-memory UserDefaults (`Application.override(\.userDefaults)`), resets
  Application demo keys / stats / `DynamicKeyStorage` memory in setUp/tearDown,
  and serializes Application access under `swift test --parallel`
- Regression: `Scripts/test-parallel.sh` (`swift test --parallel`) must pass
- Smoke: `Scripts/smoke.sh` (Unix) and `Scripts/smoke.ps1` (Windows / PowerShell) for flag/note persistence, reset, and `aps stats`
- CI: `ci.yml` matrix runs macOS + Linux (fail if either fails); Windows: `swift test` + `Scripts/smoke.ps1` on `windows-latest` (`windows-smoke.yml`)

- Encrypted-file `secret` round-trip / wrong-passphrase `secretUnlockFailed` / corrupt envelope `decodingFailed`.
- Encrypted-file `secret` parallel fresh writes share one atomically created `0600` key file.
- Secret SET with wrong passphrase leaves ciphertext unchanged; root `--state-dir` peel; safer reset; schema lock.

- Slice `profileName` writes land in parent `profile` FileState.
- Torn FileState files surface `corruptState` (exit 65) on get/watch; missing files stay nil/initial.
- Unit: schema materialize, key add, unknown_key, schemaVersion 4, peel/unlock/reset/lock tests
- Smoke: key add/remove round-trip (sh + ps1)
