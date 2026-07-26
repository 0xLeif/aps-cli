# Windows and tri-OS readiness

Status: **source CI active; binary distribution incomplete**

Last refreshed: 2026-07-26

aps builds and tests on GitHub-hosted macOS, Ubuntu, and Windows runners. That does not mean every user-facing distribution surface has parity.

## Current matrix

| Surface | macOS | Linux | Windows |
| --- | --- | --- | --- |
| Swift build and tests | Yes | Yes | Yes |
| Behavioral smoke | Bash | Bash | PowerShell |
| File and encrypted state | Tested | Tested | Core paths tested |
| Watch termination markers | SIGINT/SIGTERM | SIGINT/SIGTERM | No console-control handler |
| Published release artifact | arm64 and x86_64 | x86_64 portable bundle in current workflow | No |
| GitHub installer Action | Supported | Supported | Explicitly unsupported |
| Homebrew | Supported | Formula hardening in progress | Not applicable |

## What CI proves

- SwiftPM can resolve, build, and test aps on all three hosted runner families.
- The PowerShell smoke suite covers core get, set, dump, schema, reset, FileState, and encrypted-state behavior.
- Platform-specific imports and Combine behavior are correctly gated.
- Runtime paths use `FileManager` and `URL` rather than hard-coded Apple directories.

## What CI does not yet prove

- Windows error-exit parity for every domain error.
- Passphrase mode, corrupt envelopes, and secret reset failures on Windows.
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
5. Expand PowerShell smoke coverage for corruption, errors, concurrency, secrets, and termination.
6. Document signing and SmartScreen expectations.
