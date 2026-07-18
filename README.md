# aps

A tiny Swift CLI that [dogfoods](https://github.com/0xLeif/AppState) **AppState** outside SwiftUI: declare typed app state, get/set/watch/dump it, and show dependency injection.

Targets **macOS** (CI) and aims to stay Linux-friendly where AppState allows.

This repository is gated by the [CorvidLabs trust toolchain](https://corvidlabs.xyz/integrate/) (fledge, spec-sync, augur, attest). See `AGENTS.md`.

## Commands

```text
aps get <key>
aps set <key> <value>
aps watch <key>          # print on change (Observation + polling)
aps dump                 # print all known state as JSON
aps keys                 # list demo keys / storage kinds
aps reset <key>          # restore one key to its initial value
aps reset --all
aps --help
```

### Demo keys (fixed schema)

| Key | Type | Storage | Lifetime |
| --- | --- | --- | --- |
| `counter` | `Int` | `State` | Process (in-memory) |
| `message` | `String` | `State` | Process (in-memory) |
| `flag` | `Bool` | `StoredState` | Persisted (`UserDefaults`; CLI calls `synchronize()` so Linux flushes) |
| `note` | `String` | `FileState` | Persisted (`~/.aps/note.json`) |

Dynamic / user-declared keys are intentionally out of scope for v1.

### Dependencies

`aps` injects real services with `@AppDependency` / `Application.dependency`:

- **`clock`** : wall clock for dump timestamps
- **`jsonCoding`** : shared JSON encoder helpers for `aps dump`

## Requirements

- Swift 6.0+
- macOS 14+ (CI). Linux toolchains are supported best-effort, not gated in CI yet.
- For the trust gate locally: [corvid-trust](https://github.com/CorvidLabs/trust) (`brew install CorvidLabs/tap/corvid-trust`)
- SpecSync **5.1.1** (see `.specsync/version`). Trust CI mirrors that exact release; brew `spec-sync` latest should match.

## Build and run

```bash
git clone https://github.com/0xLeif/aps-cli.git
cd aps-cli
swift build
swift run aps --help
```

Or through fledge:

```bash
fledge lanes run verify
```

Release build:

```bash
swift build -c release
.build/release/aps dump
```

### Examples

```bash
swift run aps keys
swift run aps set counter 3
swift run aps set flag true
swift run aps set note "saved across launches"
swift run aps dump
swift run aps watch note --interval 200
swift run aps reset --all
```

`watch` uses Swift Observation for in-process updates and polls as a fallback so disk-backed `FileState` / `StoredState` changes can still surface, including updates written by another `aps` process. For `note`, polling reads `note.json` directly so AppState's FileState cache cannot hide cross-process writes.

## Tests and smoke

```bash
swift test
./Scripts/smoke.sh
```

## CI (private repo)

While this repository is **private**, every workflow runs on **macOS self-hosted** runners:

| Workflow | Runner | Role |
|----------|--------|------|
| `.github/workflows/ci.yml` | `[self-hosted, macOS]` | build / test / smoke |
| `.github/workflows/trust.yml` | `[self-hosted, macOS]` | CorvidLabs Trust gate (fledge + spec-sync + augur + attest) |

Before making the repo public, switch off self-hosted runners for fork pull requests.

## Trust toolchain

| File | Purpose |
|------|---------|
| `fledge.toml` | Tasks + `verify` lane |
| `.trust.toml` | Unified Trust policy |
| `.augur.toml` | Diff-risk thresholds |
| `.attest.json` | Provenance policy |
| `.specsync/` | SpecSync 5.1.1 config + SDD change tracking (`.specsync/version`) |
| `specs/` | Module contracts (`aps-cli`, `state-store`) |
| `AGENTS.md` | Standing rules (managed block required by CI) |

```bash
fledge trust doctor
fledge trust verify
```

## Layout

```text
Package.swift
Sources/aps/
Tests/apsTests/
specs/
Scripts/smoke.sh
.github/workflows/{ci,trust}.yml
```

## Non-goals (v1)

- No iCloud `SyncState`, Keychain `SecureState`, or SwiftData `ModelState`
- No plugin system, daemon, or network API
- No dynamic schema language: fixed demo keys only

## Related

- [AppState](https://github.com/0xLeif/AppState)
- [CorvidLabs Trust](https://github.com/CorvidLabs/trust)
- [Integrate guide](https://corvidlabs.xyz/integrate/)
