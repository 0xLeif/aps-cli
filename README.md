# aps

A tiny Swift CLI that [dogfoods](https://github.com/0xLeif/AppState) **AppState** outside SwiftUI: declare typed app state, get/set/watch/dump it, and show dependency injection.

Current release line: **0.2.0** (pre-public 0.x). Targets **macOS** (primary CI), **Linux** (smoke CI), and **Windows** (PowerShell smoke CI) where AppState allows.

This repository is gated by the [CorvidLabs trust toolchain](https://corvidlabs.xyz/integrate/) (fledge, spec-sync, augur, attest). See `AGENTS.md`.

## Commands

```text
aps get <key> [--json] [--state-dir PATH]
aps set <key> <value> [--json] [--state-dir PATH]
aps watch <key> [--count N] [--timeout SEC] [--jsonl] [--interval MS] [--state-dir PATH]
aps dump [--json] [--state-dir PATH]
aps keys [--json]
aps stats [--json] [--watch] [--count N] [--timeout SEC]
aps reset <key> [--json] [--state-dir PATH]
aps reset --all [--json] [--state-dir PATH]
aps --help
aps --version
```

State root resolution: `--state-dir` > `APS_HOME` > `~/.aps`.

### Demo keys (fixed schema)

| Key | Type | Storage | Lifetime |
| --- | --- | --- | --- |
| `counter` | `Int` | `State` | Process (in-memory) |
| `message` | `String` | `State` | Process (in-memory) |
| `flag` | `Bool` | `StoredState` | Persisted (`UserDefaults`; CLI calls `synchronize()` so Linux flushes) |
| `note` | `String` | `FileState` | Persisted (`$APS_HOME/note.json`) |
| `profile` | `{name,version}` | `FileState` | Persisted structured Codable (`$APS_HOME/profile.json`) |
| `secret` | `String` | `SecureState` | Persisted in Keychain (macOS); account `dev.leif.aps/secret` |
| `profileName` | `String` | `Slice` | Projection of `profile.name` via AppState Slice |

Dynamic / user-declared keys are intentionally out of scope for 0.x.

### SecureState / Keychain (`secret`)

- AppState `SecureState` stores the value under Keychain account `dev.leif.aps/secret` (feature `dev.leif.aps`, id `secret`).
- `aps reset secret` (and `aps reset --all`) deletes that Keychain item; get then returns an empty string.
- **macOS:** works when the process can access the login Keychain (interactive sessions and typical self-hosted macOS CI).
- **Linux / headless without Security:** Apple's Security framework is unavailable. `aps keys` still lists `secret`, `get` returns empty, and `set secret` fails with a clear Keychain-unavailable error.
- **Default CI / smoke:** Keychain round-trips are skipped. Re-enable with `APS_SMOKE_SECURESTATE=1` (Darwin) when a login Keychain is available.
- **Headless macOS CI:** if the Keychain is locked or inaccessible, set/get may fail with persistence errors. Unlock or use a runner with an available login Keychain.

### Dependencies

`aps` injects real services with `@AppDependency` / `Application.dependency`, plus one
`@ObservedDependency` consumer for AppState's observable dependency surface:

- **`clock`** : wall clock for dump timestamps (`@AppDependency`)
- **`jsonCoding`** : shared JSON encoder helpers for `aps dump` (`@AppDependency`)
- **`stats`** : process-local mutation counters (`DemoStats` / `@ObservedDependency`); `aps stats` reads them and `aps stats --watch` surfaces Combine updates

## Requirements

- Swift 6.0+
- macOS 14+ (primary CI). Linux smoke runs on `ubuntu-latest`. Windows smoke runs on `windows-latest` via `Scripts/smoke.ps1`.
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

### Fledge plugin shim

This repo ships a root `plugin.toml` so fledge can install `aps` as a live-linked plugin (`fledge-plugin-aps` v0.2.0 tracks the CLI version). Publishing to the plugin hub stays deferred until the repo is public (v1.0).

```bash
# From a clone of aps-cli:
fledge plugins install .          # live-link; rebuilds release binary via the build hook
fledge aps keys --json            # same CLI, invoked through fledge
fledge plugins validate .         # also runs in the verify lane (manifest drift fails CI)
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
swift run aps set profile '{"name":"agent","version":1}'
swift run aps dump
swift run aps watch note --interval 200 --count 2 --timeout 5
swift run aps reset --all
```

### Agent usage

```bash
swift run aps get note --json
swift run aps set counter 3 --json
swift run aps dump --json
swift run aps keys --json
swift run aps reset note --json

APS_HOME=/tmp/aps-agent swift run aps set note "isolated state"
swift run aps get note --json --state-dir /tmp/aps-agent

swift run aps watch note --count 2 --timeout 5 --jsonl

swift run aps set profile '{"name":"agent","version":1}' --json
swift run aps get profile --json
swift run aps set profileName agent --json
swift run aps stats --json
```

`watch` uses Swift Observation for in-process updates and polls as a fallback so disk-backed `FileState` / `StoredState` changes can still surface, including updates written by another `aps` process. For `note` and `profile`, polling reads the JSON files directly so AppState's FileState cache cannot hide cross-process writes.

### Multi-process FileState semantics

`aps` expects **one writer per key** at a time. Concurrent `aps set` on the same FileState key (`note` / `profile`) is last-writer-wins and is not locked: AppState writes files non-atomically, so two writers can tear a JSON file.

When a FileState file **exists but is undecodable** (torn write), `aps` does **not** fall back to AppState's initial/cached value on the direct disk path:

- `get` / `watch` for `note`, `profile`, and `profileName` fail with `corruptState` and exit code **65** (`EX_DATAERR`)
- `watch --jsonl` emits one `{"type":"error","error":"corruptState",...}` line before exiting
- Missing files still resolve to the key's initial value (same as a fresh store)

AppState itself is unchanged; this is an `aps` dogfood/CLI contract only. Repair with `aps reset <key>` (or delete the torn file under the state root).

## Tests and smoke

```bash
swift test
./Scripts/smoke.sh
# Windows / PowerShell 7+ (same behavioral coverage as smoke.sh):
pwsh ./Scripts/smoke.ps1
```

## CI

| Workflow | Runner | Role |
|----------|--------|------|
| `.github/workflows/ci.yml` | `[self-hosted, macOS]` | build / test / smoke |
| `.github/workflows/linux-smoke.yml` | `ubuntu-latest` | Linux build + smoke |
| `.github/workflows/windows-smoke.yml` | `windows-latest` | Windows build + PowerShell smoke |
| `.github/workflows/trust.yml` | `[self-hosted, macOS]` | CorvidLabs Trust gate |

While the repository is **private**, macOS workflows use self-hosted runners. Before making the repo public, switch off self-hosted runners for fork pull requests.

## Trust toolchain

| File | Purpose |
|------|---------|
| `fledge.toml` | Tasks + `verify` lane |
| `.trust.toml` | Unified Trust policy |
| `.augur.toml` | Diff-risk thresholds |
| `.attest.json` | Provenance policy |
| `.specsync/` | SpecSync 5.1.1 config + SDD change tracking (`.specsync/version`) |
| `specs/` | Module contracts (`aps-cli`, `state-store`) |
| `GOAL.md` | Active 0.x milestone checklist |
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
Scripts/smoke.ps1
GOAL.md
.github/workflows/{ci,linux-smoke,windows-smoke,trust}.yml
```

## Next goal

See [`GOAL.md`](GOAL.md) for **aps 0.2.0**: agent-ready AppState dogfood harness.


## AppState surface coverage

| AppState surface | Demo key / command | Status |
|------------------|--------------------|--------|
| `State` | `counter`, `message` | Dogfooded |
| `StoredState` | `flag` | Dogfooded |
| `FileState` | `note`, `profile` | Dogfooded |
| `SecureState` | `secret` | Dogfooded (Keychain tests/smoke opt-in) |
| `Slice` | `profileName` | Dogfooded |
| `@AppDependency` | `clock`, `jsonCoding` | Dogfooded |
| `@ObservedDependency` | `stats` / `aps stats` | Dogfooded |
| `SyncState` | — | No-go ([spike](docs/spikes/syncstate-feasibility.md)) |
| `ModelState` | — | No-go ([spike](docs/spikes/modelstate-feasibility.md)) |
| OptionalSlice / DependencySlice | — | Not planned for 0.x |

## Non-goals (0.x)

- No iCloud `SyncState` or SwiftData `ModelState` (see `docs/spikes/`)
- No in-process plugin/daemon/network API inside `aps` itself (the repo may still be a fledge plugin shim; see above)
- No dynamic schema language: fixed demo keys only
- No Windows CI until the public/1.0 flip (see [`docs/windows-readiness.md`](docs/windows-readiness.md))

## Windows / tri-OS readiness

Audit findings, per-OS gaps, and the planned `macos-latest` / `ubuntu-latest` / `windows-latest` matrix live in [`docs/windows-readiness.md`](docs/windows-readiness.md). Follow-ups: [#45](https://github.com/0xLeif/aps-cli/issues/45) (portable smoke), [#46](https://github.com/0xLeif/aps-cli/issues/46) (prove Windows build), [#40](https://github.com/0xLeif/aps-cli/issues/40) (go-public matrix).

## Related

- [AppState](https://github.com/0xLeif/AppState)
- [CorvidLabs Trust](https://github.com/CorvidLabs/trust)
- [Integrate guide](https://corvidlabs.xyz/integrate/)
