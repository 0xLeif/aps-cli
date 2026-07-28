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

- Encrypted-file v2 tests prove exact `recipientMode`, fixed scrypt metadata,
  fresh 16-byte salts, distinct repeated ciphertext, and key-file KDF omission.
- Hostile envelope tests reject unknown versions and modes, malformed KDF
  metadata, missing and null version 2 recipient modes, noncanonical base64,
  and invalid field lengths before KDF work.
- Recipient-mode mismatch and wrong credentials retain `secretUnlockFailed`
  without changing envelope or key-file bytes.
- Legacy passphrase fixtures migrate once after successful unlock; wrong
  credentials and injected replacement failures preserve exact v1 bytes, while
  restoration failure reports `rollbackFailed`.
- Legacy key-file fixtures remain readable and upgrade on the next successful
  set.
- Counting-KDF tests prove per-operation reuse for each salt and zero additional
  KDF work during unchanged encrypted-watch polls. CLI get derives once, and
  encrypted set output performs no redundant post-commit decrypt.
- Encrypted-file parallel fresh writes share one exclusively created private
  key file: exact `0600` on POSIX and a protected current-user DACL on Windows.
- Secure key-file tests cover POSIX descriptor-pinned unreadable and permissive
  repair, search-only owned parent directories, Darwin mode `0000` fail-closed
  restoration, injected repair errors, post-read permission widening,
  regular-file and symlink swaps, directory, FIFO, hostile umask, and exclusive
  creation. Windows covers
  private create/load, ACL repair when data-read and attribute access are
  absent, fail-closed security mapping when native handle synchronization
  access is absent, and directory rejection.
- POSIX state-root tests preserve safe searchable and shared-read modes, reject
  writable roots without mutation, and round-trip through a symlinked root.
  Registered encrypted watch pins the initially canonicalized root target while
  continuing descendant validation. Changed encrypted watch snapshots reload
  and revalidate key-file recipients.
- Fresh SET preserves a partial `secret.key` and fails with
  `persistenceFailed`; existing-envelope corrupt keys stay unlock failures
  without truncating key material.
- Fresh key-creation write failures remain `persistenceFailed`.
- Error and schema-table tests cover `unsupported_secret_envelope` at exit 65
  and `insecure_secret_key_file` at exit 77.
- Secret SET with wrong passphrase leaves ciphertext unchanged; root `--state-dir` peel; safer reset; schema lock.

- Slice `profileName` writes land in parent `profile` FileState.
- Torn FileState files surface `corruptState` (exit 65) on get/watch; missing files stay nil/initial.
- Unit: schema materialize, key add, unknown_key, schemaVersion 5, peel/unlock/reset/lock tests
- Smoke: key add/remove round-trip plus lexical, reserved, directory, symlink
  where supported, collision, reset, and purge path-safety cases (sh + ps1)
- Registry authority: forced seed type, storage, path, initial value, Slice
  metadata, watch, dump, reset scope, and typed output use `SchemaKeyEntry`.
- Compatibility: default flag reads JSON-encoded legacy `App/aps.flag` data and
  reset prevents it from reappearing behind `aps.user.flag`.
- Smoke: shell and PowerShell force `counter` from Int/State to
  String/FileState and verify fresh-process get, set, dump, watch, and reset.
