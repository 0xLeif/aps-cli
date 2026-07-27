# Windows and tri-OS readiness

Status: **source CI active; binary distribution incomplete**

Last refreshed: 2026-07-27

aps builds and tests on GitHub-hosted macOS, Ubuntu, and Windows runners. That does not mean every user-facing distribution surface has parity.

## Current matrix

| Surface | macOS | Linux | Windows |
| --- | --- | --- | --- |
| Swift build and tests | Yes | Yes | Yes |
| Behavioral smoke | Bash | Bash | PowerShell |
| File and encrypted state | Tested | Tested | v2 envelope and handle security tested |
| Watch termination markers | SIGINT/SIGTERM | SIGINT/SIGTERM | No console-control handler |
| Published release artifact | arm64 and x86_64 | x86_64 portable bundle in current workflow | No |
| GitHub installer Action | Supported | Supported | Explicitly unsupported |
| Homebrew | Supported | Formula hardening in progress | Not applicable |

## What CI proves

- SwiftPM can resolve, build, and test aps on all three hosted runner families.
- The PowerShell smoke suite covers core get, set, dump, schema, reset, FileState, and encrypted-state behavior.
- Platform-specific imports and Combine behavior are correctly gated.
- Runtime paths use `FileManager` and `URL` rather than hard-coded Apple directories.
- SecretStore tests cover strict v2 recipient metadata, fixed-parameter scrypt,
  legacy compatibility, recipient-mode mismatch, and unchanged encrypted-watch
  polling across the test matrix.
- Windows key-file tests exercise private creation and loading, directory and
  oversized-file rejection, and handle-based private-DACL repair. The
  implementation also fails closed for reparse points, non-disk objects, and
  foreign owners through native-handle validation.

## What CI does not yet prove

- Windows error-exit parity for every domain error.
- Full PowerShell smoke parity for legacy passphrase migration, hostile
  envelopes, and unchanged encrypted-watch cost.
- Deterministic Windows adversarial tests for reparse points, non-disk objects,
  foreign owners, unexpected access entries, and create/delete races.
- Console control handling for JSONL terminal events.
- Schema mutation races, destructive path rejection, and lock ownership under Windows semantics.
- A downloadable Windows binary or installer Action.
- Fresh-host execution of every published artifact without a Swift toolchain.

## Release policy

The README should describe aps as tri-OS source-compatible while Windows has no published asset. Do not describe the GitHub installer Action as tri-OS until a Windows asset, checksum path, and end-to-end Action test exist.

Before publishing Windows binaries:

1. Add a release build for a documented Windows architecture.
2. Define whether Swift runtime DLLs are bundled.
3. Install and execute the artifact on a clean Windows runner.
4. Add Windows selection to `.github/actions/install-aps`.
5. Expand PowerShell smoke coverage for corruption, errors, concurrency,
   legacy migration, and termination.
6. Document signing and SmartScreen expectations.
