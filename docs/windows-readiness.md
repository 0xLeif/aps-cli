# Windows readiness audit (issue #36)

Status: audit complete for 0.x groundwork. **Windows CI is deferred to the public/1.0 flip** ([#40](https://github.com/0xLeif/aps-cli/issues/40)); accept possible Windows roughness at 1.0 and patch in 1.0.x.

Date: 2026-07-18  
Auditor: agent:cursor

## Audit checklist

| Check | Result |
|-------|--------|
| No SwiftUI imports | Pass: none in `Sources/` or `Tests/` |
| Combine / `@ObservedDependency` gated | Pass: `#if canImport(Combine)` and `#if !os(Linux) && !os(Windows)` (see PR #25) |
| No ungated Security.framework | Pass: no Security.framework imports remain; `secret` uses the swift-crypto encrypted store (issue #35) |
| No hardcoded `~/Library` paths | Pass: none |
| `~/.aps` only as default | Pass: `APSPaths` uses `FileManager.homeDirectoryForCurrentUser` + `.aps`; override via `--state-dir` / `APS_HOME` |
| swift-crypto for Windows (#35) | Pass (docs): [apple/swift-crypto](https://github.com/apple/swift-crypto) supports Linux and **ARM64 Windows** via SPM (`Crypto` product). Prefer `from: "4.0.0"` (Swift 6) when #35 lands |

## Per-OS gap list

### macOS (primary today)

| Area | Status |
|------|--------|
| CI | Self-hosted `[self-hosted, macOS]` (`ci.yml`, `trust.yml`) |
| Encrypted secret store | Available; swift-crypto runs everywhere |
| ObservedDependency / Combine | Full path |
| Smoke | `Scripts/smoke.sh` |

### Linux (smoke today)

| Area | Status |
|------|--------|
| CI | GitHub-hosted `ubuntu-latest` (`linux-smoke.yml`) |
| Encrypted secret store | Available; swift-crypto runs on Windows (audit: confirm in CI) |
| ObservedDependency | Falls back to `@AppDependency` + polling for `aps stats --watch` |
| UserDefaults | `synchronize()` after flag writes (Linux flush) |
| Smoke | Same bash script |

### Windows (smoke CI via #45; full matrix at 1.0)

| Area | Status / gap |
|------|----------------|
| CI | PowerShell smoke on `windows-latest` (`windows-smoke.yml`, Swift 6.3.1+, [#45](https://github.com/0xLeif/aps-cli/issues/45)); full tri-OS matrix still [#40](https://github.com/0xLeif/aps-cli/issues/40) |
| AppState Package platforms | Declares Apple platforms only; Linux/Windows build via SPM in practice; `swift test` on `windows-latest` via `windows-smoke.yml` (#46) |
| Combine / ObservedDependency | Same gates as Linux (`!os(Windows)`) |
| SecureState | No Security; same as Linux until encrypted-file store ([#35](https://github.com/0xLeif/aps-cli/issues/35)) |
| Default state root | Should be `%USERPROFILE%\.aps` via `homeDirectoryForCurrentUser` (not hardcoded) |
| Smoke | `Scripts/smoke.ps1` (mirrors `Scripts/smoke.sh`) |
| Env tests | `setenv` / `unsetenv` in tests are POSIX; may need Windows gating when unit tests run on Windows ([#46](https://github.com/0xLeif/aps-cli/issues/46)) |
| Path separators | Help text shows `~/.aps` (Unix style); runtime uses `URL` / `FileManager` (OK) |

## Future CI matrix (public / 1.0)

From design decision 2 and [#40](https://github.com/0xLeif/aps-cli/issues/40):

```yaml
# Sketch only: land at public flip, not in 0.x private self-hosted setup.
strategy:
  matrix:
    os: [macos-latest, ubuntu-latest, windows-latest]
runs-on: ${{ matrix.os }}
# Replace self-hosted macOS runners; add fork-PR safety.
```

Suggested jobs:

| Job | Runner | Role |
|-----|--------|------|
| build-test-smoke | `macos-latest` | `swift test` + smoke |
| build-test-smoke | `ubuntu-latest` | same (supersedes standalone linux-smoke or merges with it) |
| build-test-smoke | `windows-latest` | `swift test` + portable smoke ([#45](https://github.com/0xLeif/aps-cli/issues/45)) |
| trust | `macos-latest` | CorvidLabs trust gate (after self-hosted decommission) |

## Cheap fixes landed with this audit

- Platform-neutral assertion for default `APSPaths` suffix (`.aps` path component, not `/.aps` string).
- Clarifying comments on `APSPaths` default resolution for Windows home directories.
- README link to this document.

## Ticketed for v1.0.0 (not fixed here)

| Issue | Topic |
|-------|--------|
| [#40](https://github.com/0xLeif/aps-cli/issues/40) | Go-public: tri-OS GitHub-hosted matrix, decommission self-hosted |
| [#45](https://github.com/0xLeif/aps-cli/issues/45) | Portable Windows smoke |
| [#46](https://github.com/0xLeif/aps-cli/issues/46) | Prove AppState + aps on `windows-latest` |
| [#35](https://github.com/0xLeif/aps-cli/issues/35) | Encrypted-file secret store via swift-crypto (replaces Keychain on non-Apple) |
| [#31](https://github.com/0xLeif/aps-cli/issues/31) | Exit-code taxonomy (owned by kimi; rebase after this train) |

## Explicit non-goals of this audit ticket (#36)

- Full public/1.0 tri-OS matrix (still [#40](https://github.com/0xLeif/aps-cli/issues/40)); #45 adds smoke-only `windows-latest`.
- Implementing #35 encrypted secrets.
- Changing AppState upstream.
