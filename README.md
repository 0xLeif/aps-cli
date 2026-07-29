# aps

**State you can see. Contracts you can trust.**

aps is a small Swift CLI that brings [AppState](https://github.com/0xLeif/AppState) outside SwiftUI. Declare typed state, read it, change it, watch it, and expose the same stable contract to humans, agents, and CI.

Source version: **1.1.0**. The latest published tag remains
**1.0.0** until the reviewed v1.1.0 candidate is signed and published; see
[release readiness](docs/release-readiness.md). The source and CI target
**macOS**, **Linux**, and **Windows**, while published binary availability
varies by platform.

Keys live in `<state-root>/schema.json`, with demo defaults materialized on first use. Start with the [documentation map](docs/README.md) or the [dynamic schema design](docs/design/dynamic-schema.md).

This repository is gated by the [CorvidLabs trust toolchain](https://corvidlabs.xyz/integrate/) (fledge, spec-sync, augur, attest). See `AGENTS.md`.

The v1.1.0 release workflow introduces a stricter boundary than ordinary pull
requests: the exact tag commit must carry passing-test evidence signed by the
pinned `human:leif` Attest key. Both tag pushes and manual backfills use that
gate before artifact upload. See the [release provenance runbook](docs/release-provenance.md).

## Project status

| Surface | Status |
| --- | --- |
| Serial and four-worker Swift verification lanes | Passing |
| macOS, Linux, and Windows source CI | Active |
| Homebrew and release packaging | Portable bundle contract prepared for v1.1.0 |
| Dynamic schema and secret safety | Safe paths, strict v2 envelopes, and transactional destructive operations |
| SpecSync contracts | Passing with 2 active module specs |

The current release remains useful for local AppState exploration. The next
release hardens passphrase secrets for local use; production automation still
depends on the remaining distribution items in
[release readiness](docs/release-readiness.md).

## Install

**Homebrew:**

```bash
brew install 0xLeif/tap/aps
```

**fledge plugin** (this repo is the plugin; no separate hub repo needed):

```bash
fledge plugins install 0xLeif/aps-cli
fledge aps keys --json
```

**Mint** (builds the SwiftPM executable from source):

```bash
mint install 0xLeif/aps-cli
```

**Source** (Swift 6.0+):

```bash
git clone https://github.com/0xLeif/aps-cli.git
cd aps-cli && swift build -c release
.build/release/aps --help
```

**Foreign GitHub Actions workflows:** use the reusable composite Action to install the release binary without a Swift toolchain:

```yaml
- uses: 0xLeif/aps-cli/.github/actions/install-aps@8e2108601b182584e59b3e534b67199247593a0a
  with:
    version: 1.1.0
- run: aps set note "run-${{ github.run_id }}"
```

The Action selects the release asset for Linux x64, macOS x64, or macOS arm64, verifies its `.sha256` sidecar before moving it into the job-scoped `${RUNNER_TEMP}/aps/bin`, and adds that directory to `PATH`. Linux releases are portable tar bundles containing the Swift runtime libraries, so no Swift toolchain is needed. The existing v1.0.0 release predates this Action and does not contain the portable Linux bundle; use a release built by the current release workflow for Linux. The Action defaults `APS_HOME` to `${RUNNER_TEMP}/aps-home` through `GITHUB_ENV`; an existing `APS_HOME` is preserved. Pin the Action to a release tag or pass an explicit semantic `version`. Windows is not supported until a Windows release asset is published.

## Commands

```text
aps [--state-dir PATH] <subcommand> ...
aps get <key> [--json] [--state-dir PATH]
aps set <key> <value> [--json] [--state-dir PATH]
aps watch <key> [--count N] [--timeout SEC] [--jsonl] [--interval MS] [--state-dir PATH]
aps dump [--json] [--state-dir PATH]
aps keys [--json] [--state-dir PATH]
aps key add|remove|list ...
aps stats [--json] [--watch] [--count N] [--timeout SEC] [--state-dir PATH]
aps reset <key> [--json] [--state-dir PATH]
aps reset --all [--json] [--state-dir PATH]
aps reset --registered [--json] [--state-dir PATH]
aps schema [--json] [--state-dir PATH]
aps --help
aps --version
```

State root resolution: `--state-dir` (root form `aps --state-dir PATH <cmd>` or on the subcommand; subcommand wins) > `APS_HOME` > `~/.aps`.

### Default demo keys (seed schema)

On first use, aps materializes `<state-root>/schema.json` with these seed keys:

| Key | Type | Storage | Lifetime |
| --- | --- | --- | --- |
| `counter` | `Int` | `State` | Process (in-memory) |
| `message` | `String` | `State` | Process (in-memory) |
| `flag` | `Bool` | `StoredState` | Persisted (`UserDefaults`; CLI calls `synchronize()` so Linux flushes) |
| `note` | `String` | `FileState` | Persisted (`$APS_HOME/note.json`) |
| `profile` | `{name,version}` | `FileState` | Persisted structured Codable (`$APS_HOME/profile.json`) |
| `secret` | `String` | `EncryptedFile` | Persisted encrypted under the state root (`secret.enc`) |
| `profileName` | `String` | `Slice` | Projection of `profile.name` via AppState Slice |

Add or remove keys at runtime:

```bash
aps key add smokeNote --type String --storage FileState --path smoke-note.json --initial ''
aps set smokeNote hello
aps key add settings --type object --storage FileState --path settings.json \
  --field name=String --field retries=Int \
  --initial '{"name":"agent","retries":3,"features":{"watch":true}}'
aps key add settingsName --type String --storage Slice \
  --slice-of settings --slice-field name --initial ''
aps get settings --json
aps key remove smokeNote --purge
aps key list --json
```

`--field NAME=TYPE` is repeatable for object keys. Every declared field is
required and type-checked, while undeclared fields are preserved. Object
values are structural JSON and may recursively contain nulls, booleans,
integers, finite doubles, strings, arrays, and objects. A Slice is valid only
when its parent object declares `sliceField` with the same type as the Slice.

Persistent schema paths must be portable relative file paths below the state root. `aps` rejects absolute or traversing paths, reserved APS files, case or Unicode-equivalent collisions, directories, special files, and paths that traverse symbolic links. Reset and purge delete only a validated regular-file leaf.

`schema.json` is authoritative for every registered name, including the seven
default seed names. `DemoKey` defines only the schema materialized for a new
state root. After `key add --force`, get, set, reset, watch, dump, type parsing,
and machine output all use the replacement entry. Force is non-destructive:
changing storage or path does not migrate, purge, or read the former adapter's
data, so changing back can reveal it again.

### Encrypted-file secret store (`secret`)

`secret` is backed by a v2 encrypted envelope under the state root, not the
Keychain. The payload uses ephemeral X25519 ECDH, HKDF-SHA256, and
ChaCha20-Poly1305 through
[swift-crypto](https://github.com/apple/swift-crypto).

- **`secret.enc`:** v2 JSON records `recipientMode` plus the base64 ephemeral
  public key, nonce, ciphertext, and tag. Nothing plaintext is written at rest.
- **Key-file mode (default):** v2 records `recipientMode: "keyFile"` and omits
  `kdf`. The X25519 key is generated at `<state-root>/secret.key`. POSIX access
  uses no-follow handles, requires current-user ownership and exact mode `0600`,
  and safely repairs permissions through the open handle. Windows rejects
  reparse, directory, non-disk, and foreign-owned handles and requires a
  protected private DACL for the current user. New files are exclusive and
  private before key bytes are written. The key and ciphertext share a state
  root, so this mode does not protect against compromise of the whole root.
- **Passphrase mode:** set `APS_SECRET_PASSPHRASE`. Every seal creates a fresh
  cryptographically random 16-byte salt and derives a 32-byte X25519 private key
  with the public CryptoExtras scrypt API at `N=131072`, `r=8`, `p=1`. This
  profile costs approximately 128 MiB per derivation. aps depends on
  apple/swift-crypto `4.0.0..<4.4.0`; 4.4+ requires Swift tools 6.1 while aps
  retains its Swift 6.0 floor.
- **Strict metadata:** v2 validates the exact JSON shape, canonical base64,
  cryptographic field lengths, mode/KDF combination, 16-byte salt, and fixed
  KDF constants before invoking scrypt. Unknown version or mode returns
  `unsupported_secret_envelope`; malformed metadata returns `decoding_failed`.
- **Mode binding:** a v2 envelope opens only with its recorded recipient mode.
  aps never falls back between passphrase and key-file modes. A mismatch or
  wrong credential returns `secret_unlock_failed` without changing envelope or
  key bytes.
- **Legacy compatibility:** unversioned key-file envelopes remain readable and
  upgrade on the next successful set. A successfully unlocked unversioned
  passphrase envelope migrates once, under `secret.store.lock`, to v2 with a
  fresh salt. A wrong passphrase does not migrate. Any detected migration
  failure restores and verifies the exact original bytes before reporting
  failure; a restoration failure returns `rollback_failed`.
- **Bounded KDF work:** derived passphrase keys are cached only inside one
  SecretStore operation and only for a validated salt and the fixed profile.
  Encrypted watch compares complete envelope bytes first, so unchanged polls do
  no decoding, decryption, or scrypt work.
- An unsafe `secret.key` returns `insecure_secret_key_file` without following,
  replacing, truncating, or deleting that path. Corrupt envelope data blocks
  get and set until `aps reset secret` or repair.
- **Interactive opt-in:** with `APS_SECRET_USE_PASSPHRASE=1` on a TTY, aps prompts once itself (its own getpass prompt, not macOS Keychain's).
- `aps reset secret` takes the secret-store lock, stages and verifies deletion
  of `secret.enc`, restores the envelope after a detected verification failure,
  and keeps the shared key file for future writes.
- `aps reset --all` restores currently registered seed names through their live schema entries (safe for agent keys). Removed seed names stay removed. Use `aps reset --registered` to restore every key in `schema.json`. Bulk reset is deterministic and fail-fast; JSON success and error payloads report reset, failed, and not-attempted keys.
- Registered writes and resets resolve under the schema lock and retain it
  through verified persistence. `aps key remove NAME --purge` keeps that lock
  through storage deletion, so a stale writer cannot recreate purged data. A
  detected purge failure restores the original schema before returning an
  error. This is detected-error transactional behavior, not crash atomicity.
- The previous AppState `SecureState` / Keychain backend was replaced: ad-hoc signed CLI binaries can never earn durable Keychain trust, so every access prompted for a password. AppState itself is unchanged; SecureState remains dogfooded in [AppStateExamples](https://github.com/0xLeif/AppStateExamples).

### Dependencies

`aps` injects real services with `@AppDependency` / `Application.dependency`, plus one
`@ObservedDependency` consumer for AppState's observable dependency surface:

- **`clock`** : wall clock for dump timestamps (`@AppDependency`)
- **`jsonCoding`** : shared JSON encoder helpers for `aps dump` (`@AppDependency`)
- **`stats`** : process-local mutation counters (`DemoStats` / `@ObservedDependency`); `aps stats` reads them and `aps stats --watch` surfaces Combine updates

## Requirements

- Swift 6.0+
- apple/swift-crypto `4.0.0..<4.4.0`, including the public `CryptoExtras`
  scrypt product
- macOS 14+ (primary CI on `macos-latest`). Linux smoke runs on `ubuntu-latest`. Windows smoke runs on `windows-latest` via `Scripts/smoke.ps1`.
- For the trust gate locally: [corvid-trust](https://github.com/CorvidLabs/trust) (`brew install CorvidLabs/tap/corvid-trust`)
- SpecSync **5.2.0** (see `.specsync/version`). Trust CI mirrors that exact release; brew `spec-sync` latest should match.
- Attest **1.0.0** for the local release-provenance contract test. Ordinary
  Swift build and test commands do not require the release signing key.

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

This repo ships a root `plugin.toml`, so aps-cli is itself the fledge plugin
(`fledge-plugin-aps` v1.1.0 tracks the CLI version). Install straight from this
repo: `fledge plugins install 0xLeif/aps-cli`. The earlier hub snapshot repo
(0xLeif/fledge-plugin-aps) is retired; aps-cli is the only source of truth.

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
swift run aps reset --registered
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
swift run aps --state-dir /tmp/aps-agent get note --json
swift run aps get note --json --state-dir /tmp/aps-agent

swift run aps watch note --count 2 --timeout 5 --jsonl

swift run aps set profile '{"name":"agent","version":1}' --json
swift run aps get profile --json
swift run aps set profileName agent --json
swift run aps stats --json

swift run aps key add agentNote --type String --storage FileState --path agent-note.json --initial ''
```

`aps schema` is the contract endpoint: one cacheable JSON document with `cliVersion`, integer `schemaVersion`
(bumped when the document shape changes; currently **6**), live `userSchema` meta (`formatVersion`, `keyCount`, `hash`),
state-root precedence, every registered key and command, payload shapes, and the error-code table. Live values stay in
`aps dump`. ArgumentParser's full command tree is also available as JSON via
`aps <cmd> --experimental-dump-help`.

`watch` polls the adapter selected by the resolved registry entry, so forced seed replacements and disk-backed `FileState` / `StoredState` changes surface even when another `aps` process writes them. The default `flag` can read legacy AppState `App/aps.flag` data when `aps.user.flag` is absent; new registry writes use the canonical `aps.user.<name>` namespace.

### Output modes (human and agent)

`aps` follows the git porcelain rule: **human output may be pretty, machine output is a frozen contract.**

- On a TTY: `keys` renders an aligned table with a bold header, JSON is pretty-printed, and semantic color is used sparingly (set `NO_COLOR` to disable).
- When piped: `keys` is byte-stable TSV with no ANSI escapes, and all JSON is single-line compact.
- Object values remain JSON objects in machine output. They are never
  stringified, and recursively nested arrays, objects, nulls, and numeric
  values retain their structure and numeric value. Equivalent integral JSON
  spellings such as `1`, `1.0`, and `1e0` may canonicalize to `1`.
- `watch --json` is an alias for `--jsonl`; `keys --quiet` prints key names only (handy for `xargs aps reset`).
- Shell completions: `aps --generate-completion-script bash|zsh|fish` (install into your shell's completion directory).

`watch` termination is observable in both channels. Exit codes: **0** when `--count` is satisfied, **124** on `--timeout` (GNU convention), **130** on SIGINT, **143** on SIGTERM. In `--jsonl` mode the stream ends with a terminal `{"type":"end","reason":"count|timeout|sigint|sigterm",...}` event and never contains non-JSON lines; in human mode a one-line summary goes to stderr. An unbounded watch prints a one-time stderr hint suggesting `--count` / `--timeout`.

### Multi-process FileState semantics

`aps` expects **one writer per key** unless a storage adapter documents stronger behavior. Profile and Slice read-modify-write operations use a lock. The seed `note` FileState path still relies on AppState's unlocked write behavior, so concurrent writers can tear that JSON file.

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
| 64 | EX_USAGE | caller-fixable input: bad key/flags, invalid value, `unknown_key`, `schema_conflict` |
| 65 | EX_DATAERR | corrupt data, invalid schema, or `unsupported_secret_envelope` |
| 69 | EX_UNAVAILABLE | the configured passphrase or key cannot unlock the envelope |
| 70 | EX_SOFTWARE | internal bug |
| 73 | EX_CANTCREAT | persistence or schema rollback did not complete |
| 77 | EX_NOPERM | `secret.key` ownership, type, or privacy could not be proven |

64 means fix the invocation; 65+ means environment or data; 70 means an aps bug. Missing state files are not errors: they mean the initial value.

With `--json` / `--jsonl`, or when `APS_ERROR_JSON=1`, stderr additionally gets one structured envelope:

```json
{"error":{"code":"invalid_value","hint":"Run `aps keys` to see expected types per key.","message":"Invalid value 'nope' for counter (Int)"}}
```

`code` is stable and safe to match on: `invalid_value`, `encoding_failed`,
`decoding_failed`, `persistence_failed`, `corrupt_state`, `schema_invalid`,
`unknown_key`, `schema_conflict`, `secret_unlock_failed`,
`unsupported_secret_envelope`, `insecure_secret_key_file`, and
`rollback_failed`.

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
| `.github/workflows/ci.yml` | `macos-latest` | build / test / smoke |
| `.github/workflows/linux-smoke.yml` | `ubuntu-latest` | Linux build + smoke |
| `.github/workflows/windows-smoke.yml` | `windows-latest` | Windows `swift test` + PowerShell smoke |
| `.github/workflows/trust.yml` | `macos-latest` | CorvidLabs Trust gate |

## Trust toolchain

| File | Purpose |
|------|---------|
| `fledge.toml` | Tasks + `verify` lane |
| `.trust.toml` | Unified Trust policy |
| `.augur.toml` | Diff-risk thresholds |
| `.attest.json` | Provenance policy |
| `.attest-release.json` | Strict release-only provenance policy |
| `.specsync/` | SpecSync 5.2.0 config + SDD change tracking (`.specsync/version`) |
| `specs/` | Module contracts (`aps-cli`, `state-store`) |
| `GOAL.md` | Shipped 1.0.0 release record |
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
Scripts/release-provenance-gate.sh
Scripts/test-release-provenance.sh
GOAL.md
LICENSE
.github/workflows/{ci,linux-smoke,windows-smoke,trust,release,post-release-formula}.yml
```

## Next goal

**1.0.0** is shipped and public: [release v1.0.0](https://github.com/0xLeif/aps-cli/releases/tag/v1.0.0) and [`GOAL.md`](GOAL.md) record.

The next release will:

- make dynamic schema paths and destructive operations safe by construction;
- make the runtime registry authoritative for every key;
- align portable Linux, Homebrew, and GitHub Action distribution;
- ship the implemented v2 passphrase and key-file hardening;
- require signed passing-test provenance on the exact release commit;
- rehearse installation from real release artifacts on clean hosts.

The full evidence, blockers, and exit criteria live in [docs/release-readiness.md](docs/release-readiness.md).

## Product site design system

The aps product site consumes
[`tofu-ux/0x`](https://github.com/tofu-ux/0x) as its token, component, and
theme source. [`0xLeif/0x`](https://github.com/0xLeif/0x) is the contribution
fork for collaborating with tofu-ux. Until `@tofu-ux/0x` is published to npm,
the site vendors one reviewed upstream Git commit through
`Scripts/sync-0x.sh`; `Scripts/test-0x-vendor.sh` verifies exact asset hashes.
Product-specific Swift examples and the live state tape remain owned here.
Colors, typography, theme behavior, and shared primitives remain owned by 0x.


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
| `SyncState` | - | No-go ([spike](docs/spikes/syncstate-feasibility.md)) |
| `ModelState` | - | No-go ([spike](docs/spikes/modelstate-feasibility.md)) |
| OptionalSlice / DependencySlice | - | Not planned |

## Non-goals

- No iCloud `SyncState` or SwiftData `ModelState` (see `docs/spikes/`)
- No in-process plugin/daemon/network API inside `aps` itself (the repo may still be a fledge plugin shim; see above)

## Windows / tri-OS readiness

Audit findings and per-OS gaps live in [`docs/windows-readiness.md`](docs/windows-readiness.md). CI runs the full matrix on GitHub-hosted runners (`macos-latest`, `ubuntu-latest`, `windows-latest`).

## Design

- Documentation map: [`docs/README.md`](docs/README.md)
- Release readiness: [`docs/release-readiness.md`](docs/release-readiness.md)
- Dynamic / user-defined keys: [`docs/design/dynamic-schema.md`](docs/design/dynamic-schema.md) (issues [#39](https://github.com/0xLeif/aps-cli/issues/39), [#62](https://github.com/0xLeif/aps-cli/issues/62)-[#64](https://github.com/0xLeif/aps-cli/issues/64))
- Go-public checklist: [#40](https://github.com/0xLeif/aps-cli/issues/40)

## Related

- [AppState](https://github.com/0xLeif/AppState)
- [CorvidLabs Trust](https://github.com/CorvidLabs/trust)
- [Integrate guide](https://corvidlabs.xyz/integrate/)
