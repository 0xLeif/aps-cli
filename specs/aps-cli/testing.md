# Testing -  APS CLI

- Unit: DemoKey metadata, parseBool, invalid set values
- Integration: StateStore round-trips via `@testable import aps`
- Unit: ObservedDependency stats mutation + Combine observation
- Smoke: `Scripts/smoke.sh` (Unix) and `Scripts/smoke.ps1` (Windows / PowerShell) for flag/note persistence, reset, and `aps stats`
- Windows CI: `swift test` + `Scripts/smoke.ps1` on `windows-latest` (`windows-smoke.yml`)

- Encrypted-file `secret` round-trip / wrong-passphrase `secretUnlockFailed` / corrupt envelope `decodingFailed`.

- Slice `profileName` writes land in parent `profile` FileState.
- Torn FileState files surface `corruptState` (exit 65) on get/watch; missing files stay nil/initial.
