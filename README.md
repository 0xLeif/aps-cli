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
| `secret` | `String` | `EncryptedFile` | Persisted encrypted under the state root (`secret.enc`) |
| `profileName` | `String` | `Slice` | Projection of `profile.name` via AppState Slice |

Dynamic / user-declared keys are intentionally out of scope for 0.x.

### Encrypted-file secret store (`secret`)

`secret` is backed by an age-style encrypted envelope under the state root (issue #35), not the Keychain: ephemeral X25519 ECDH + HKDF + ChaCha20-Poly1305 via [swift-crypto](https://github.com/apple/swift-crypto), the same construction as [AlgoChat](https://github.com/CorvidLabs/swift-algochat)'s message encryptor.

- **`secret.enc`** holds the encrypted envelope (ephemeral public key, nonce, ciphertext, tag, base64 JSON). Nothing plaintext at rest.
- **Key file mode (default):** a recipient key is generated on first use at `<state-root>/secret.key` (base64 X25519, mode 0600), like an SSH key. Zero prompts, works headless and in CI, on every OS.
- **Passphrase mode:** set `APS_SECRET_PASSPHRASE` to derive the key from a passphrase via HKDF-SHA256 (no key file). Wrong passphrases fail loudly with `secretUnlockFailed`.
- **Interactive opt-in:** with `APS_SECRET_USE_PASSPHRASE=1` on a TTY, aps prompts once itself (its own getpass prompt, not macOS Keychain's).
- `aps reset secret` deletes `secret.enc`; the key file is kept for future writes.
- The previous AppState `SecureState` / Keychain backend was replaced: ad-hoc signed CLI binaries can never earn durable Keychain trust, so every access prompted for a password. AppState itself is unchanged; SecureState remains dogfooded in [AppStateExamples](https://github.com/0xLeif/AppStateExamples).

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
swift run aps schema                # self-describing contract: keys, commands, payloads, errors
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

`aps schema` is the contract endpoint: one cacheable JSON document with `cliVersion`, integer `schemaVersion` (bumped on any contract change, so agents can detect drift), state-root precedence, every key and command, payload shapes, and the error-code table. It is static contract only; live state stays in `aps dump`. ArgumentParser's full command tree is also available as JSON via `aps <cmd> --experimental-dump-help`.

`watch` uses Swift Observation for in-process updates and polls as a fallback so disk-backed `FileState` / `StoredState` changes can still surface, including updates written by another `aps` process. For `note` and `profile`, polling reads the JSON files directly so AppState's FileState cache cannot hide cross-process writes.

### Output modes (human and agent)

`aps` follows the git porcelain rule: **human output may be pretty, machine output is a frozen contract.**

- On a TTY: `keys` renders an aligned table with a bold header, JSON is pretty-printed, and semantic color is used sparingly (set `NO_COLOR` to disable).
- When piped: `keys` is byte-stable TSV with no ANSI escapes, and all JSON is single-line compact.
- `watch --json` is an alias for `--jsonl`; `keys --quiet` prints key names only (handy for `xargs aps reset`).
- Shell completions: `aps --generate-completion-script bash|zsh|fish` (install into your shell's completion directory).

`watch` termination is observable in both channels. Exit codes: **0** when `--count` is satisfied, **124** on `--timeout` (GNU convention), **130** on SIGINT, **143** on SIGTERM. In `--jsonl` mode the stream ends with a terminal `{"type":"end","reason":"count|timeout|sigint|sigterm",...}` event and never contains non-JSON lines; in human mode a one-line summary goes to stderr. An unbounded watch prints a one-time stderr hint suggesting `--count` / `--timeout`.

### Multi-process FileState semantics

`aps` expects **one writer per key** at a time. Concurrent `aps set` on the same FileState key (`note` / `profile`) is last-writer-wins and is not locked: AppState writes files non-atomically, so two writers can tear a JSON file.

When a FileState file **exists but is undecodable** (torn write), `aps` does **not** fall back to AppState's initial/cached value on the direct disk path:

- `get` / `watch` for `note`, `profile`, and `profileName` fail with `corruptState` and exit code **65** (`EX_DATAERR`)
- `watch --jsonl` emits one `{"type":"error","error":"corruptState",...}` line before exiting
- Missing files still resolve to the key's initial value (same as a fresh store)

AppState itself is unchanged; this is an `aps` dogfood/CLI contract only. Repair with `aps reset <key>` (or delete the torn file under the state root).

### Error contract

Domain errors always print a human line to stderr and keep stdout empty, with a sysexits-aligned exit code:

| Code | Meaning | When |
|------|---------|------|
| 0 | success | stdout contract satisfied |
| 64 | EX_USAGE | caller-fixable input: bad key/flags, invalid value |
| 65 | EX_DATAERR | corrupt or undecodable persisted state (see Multi-process FileState semantics) |
| 69 | EX_UNAVAILABLE | `secret` on a platform without Apple Security |
| 70 | EX_SOFTWARE | internal bug |
| 73 | EX_CANTCREAT | write did not persist (unwritable state root) |

64 means fix the invocation; 65+ means environment or data; 70 means an aps bug. Missing state files are not errors: they mean the initial value.

With `--json` / `--jsonl`, or when `APS_ERROR_JSON=1`, stderr additionally gets one structured envelope:

```json
{"error":{"code":"invalid_value","hint":"Run `aps keys` to see expected types per key.","message":"Invalid value 'nope' for counter (Int)"}}
```

`code` is stable and safe to match on: `invalid_value`, `encoding_failed`, `decoding_failed`, `persistence_failed`, `keychain_unavailable`, `corrupt_state`.

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
| `.github/workflows/windows-smoke.yml` | `windows-latest` | Windows `swift test` + PowerShell smoke |
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
docs/design/
Scripts/smoke.sh
Scripts/smoke.ps1
GOAL.md
.github/workflows/{ci,linux-smoke,windows-smoke,trust}.yml
```

## Next goal

0.x dogfood harness is largely complete (see [`GOAL.md`](GOAL.md)). Next milestone is **v1.0.0**: dynamic schema ([RFC](docs/design/dynamic-schema.md)) and go-public ([#40](https://github.com/0xLeif/aps-cli/issues/40)).


## AppState surface coverage

| AppState surface | Demo key / command | Status |
|------------------|--------------------|--------|
| `State` | `counter`, `message` | Dogfooded |
| `StoredState` | `flag` | Dogfooded |
| `FileState` | `note`, `profile` | Dogfooded |
| `SecureState` | (none) | Not dogfooded here; moved to AppStateExamples after the Keychain prompt issue (issue #35) |
| `Slice` | `profileName` | Dogfooded |
| `@AppDependency` | `clock`, `jsonCoding` | Dogfooded |
| `@ObservedDependency` | `stats` / `aps stats` | Dogfooded |
| `SyncState` | — | No-go ([spike](docs/spikes/syncstate-feasibility.md)) |
| `ModelState` | — | No-go ([spike](docs/spikes/modelstate-feasibility.md)) |
| OptionalSlice / DependencySlice | — | Not planned for 0.x |

## Non-goals (0.x)

- No iCloud `SyncState` or SwiftData `ModelState` (see `docs/spikes/`)
- No in-process plugin/daemon/network API inside `aps` itself (the repo may still be a fledge plugin shim; see above)
- No runtime user-defined keys in 0.x (fixed demo keys only; 1.0 design is [`docs/design/dynamic-schema.md`](docs/design/dynamic-schema.md))

## Windows / tri-OS readiness

Audit findings and per-OS gaps live in [`docs/windows-readiness.md`](docs/windows-readiness.md). Linux and Windows smoke CI already run on GitHub-hosted runners; the full public tri-OS matrix and self-hosted decommission are [#40](https://github.com/0xLeif/aps-cli/issues/40).

## 1.0 design

- Dynamic / user-defined keys: [`docs/design/dynamic-schema.md`](docs/design/dynamic-schema.md) (issue [#39](https://github.com/0xLeif/aps-cli/issues/39))
- Go-public checklist: [#40](https://github.com/0xLeif/aps-cli/issues/40)

## Related

- [AppState](https://github.com/0xLeif/AppState)
- [CorvidLabs Trust](https://github.com/CorvidLabs/trust)
- [Integrate guide](https://corvidlabs.xyz/integrate/)
