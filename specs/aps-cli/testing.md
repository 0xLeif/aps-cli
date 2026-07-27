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
- Fresh SET recovers a partial `secret.key` without envelope; existing-envelope corrupt keys stay unlock failures without truncating key material.
- Fresh key-creation write failures remain `persistenceFailed`.
- Secret SET with wrong passphrase leaves ciphertext unchanged; root `--state-dir` peel; safer reset; schema lock.

- Slice `profileName` writes land in parent `profile` FileState.
- Torn FileState files surface `corruptState` (exit 65) on get/watch; missing files stay nil/initial.
- Unit: schema materialize, key add, unknown_key, schemaVersion 4, peel/unlock/reset/lock tests
- Smoke: key add/remove round-trip plus lexical, reserved, directory, symlink
  where supported, collision, reset, and purge path-safety cases (sh + ps1)
- Registry authority: forced seed type, storage, path, initial value, Slice
  metadata, watch, dump, reset scope, and typed output use `SchemaKeyEntry`.
- Compatibility: default flag reads JSON-encoded legacy `App/aps.flag` data and
  reset prevents it from reappearing behind `aps.user.flag`.
- Smoke: shell and PowerShell force `counter` from Int/State to
  String/FileState and verify fresh-process get, set, dump, watch, and reset.
