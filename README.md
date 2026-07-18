# aps

A tiny Swift CLI that [dogfoods](https://github.com/0xLeif/AppState) **AppState** outside SwiftUI: declare typed app state, get/set/watch/dump it, and show dependency injection.

Current release line: **0.2.0** (pre-public 0.x). Targets **macOS** (primary CI) and **Linux** (smoke CI) where AppState allows.

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

Dynamic / user-declared keys are intentionally out of scope for 0.x.

### Dependencies

`aps` injects real services with `@AppDependency` / `Application.dependency`, plus one
`@ObservedDependency` consumer for AppState's observable dependency surface:

- **`clock`** : wall clock for dump timestamps (`@AppDependency`)
- **`jsonCoding`** : shared JSON encoder helpers for `aps dump` (`@AppDependency`)
- **`stats`** : process-local mutation counters (`DemoStats` / `@ObservedDependency`); `aps stats` reads them and `aps stats --watch` surfaces Combine updates

## Requirements

- Swift 6.0+
- macOS 14+ (primary CI). Linux smoke runs on `ubuntu-latest`.
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
```

`watch` uses Swift Observation for in-process updates and polls as a fallback so disk-backed `FileState` / `StoredState` changes can still surface, including updates written by another `aps` process. For `note` and `profile`, polling reads the JSON files directly so AppState's FileState cache cannot hide cross-process writes.

## Tests and smoke

```bash
swift test
./Scripts/smoke.sh
```

## CI

| Workflow | Runner | Role |
|----------|--------|------|
| `.github/workflows/ci.yml` | `[self-hosted, macOS]` | build / test / smoke |
| `.github/workflows/linux-smoke.yml` | `ubuntu-latest` | Linux build + smoke |
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
GOAL.md
.github/workflows/{ci,linux-smoke,trust}.yml
```

## Next goal

See [`GOAL.md`](GOAL.md) for **aps 0.2.0**: agent-ready AppState dogfood harness.

## Non-goals (0.x)

- No iCloud `SyncState`, Keychain `SecureState`, or SwiftData `ModelState`
- No plugin system, daemon, or network API
- No dynamic schema language: fixed demo keys only

## Related

- [AppState](https://github.com/0xLeif/AppState)
- [CorvidLabs Trust](https://github.com/CorvidLabs/trust)
- [Integrate guide](https://corvidlabs.xyz/integrate/)
