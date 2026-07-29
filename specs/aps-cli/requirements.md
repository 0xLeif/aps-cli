---
spec: aps-cli.spec.md
---

# Requirements -  APS CLI

## Functional

### REQ-aps-cli-001

The default materialized schema SHALL include `profile`, `secret`, and `profileName` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile`, `secret`, and `profileName` on a fresh state root.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.
- `aps set secret ...` round-trips through get/dump/reset.

### REQ-aps-cli-002

`set` SHALL reject values that cannot parse to the key's type and exit non-zero via `APSError.invalidValue`.

Acceptance Criteria
- Non-integer `counter` values fail with an invalid-value message.
- Non-boolean `flag` values fail with an invalid-value message.
- `APSError.description` names the key and expected type.

### REQ-aps-cli-003

Process-local `State` keys SHALL not be required to persist across process boundaries.

Acceptance Criteria
- `counter` and `message` are documented and tested as process-local.
- `flag` (`StoredState`) and `note` (`FileState`) persist across processes after a successful set.

### REQ-aps-cli-004

`watch` SHALL print the current value first and flush subsequent distinct values promptly, including cross-process `FileState` writes to `note`.

Acceptance Criteria
- The first emitted line is the current value.
- Non-TTY stdout still surfaces each change without waiting for process exit.
- An external write to `note.json` is observed within one poll interval without relying on AppState's FileState cache.

### REQ-aps-cli-005

`APSError` SHALL cover `invalidValue`, `encodingFailed`, `decodingFailed`,
`persistenceFailed`, `secretUnlockFailed`, `unsupportedSecretEnvelope`,
`insecureSecretKeyFile`, `corruptState`, `schemaInvalid`, `unknownKey`,
`schemaConflict`, and `rollbackFailed`.

Acceptance Criteria
- Each case has an actionable `description`, stable `code`, and taxonomy `exitCode`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.
- `corruptState` / `schemaInvalid` use exit 65; `unknownKey` / `schemaConflict` use exit 64.
- `unsupportedSecretEnvelope` uses code `unsupported_secret_envelope` and exit 65.
- `insecureSecretKeyFile` uses code `insecure_secret_key_file` and exit 77.

### REQ-aps-cli-010

`get`, `set`, `dump`, `keys`, and `reset` SHALL support `--json` machine-readable output.

Acceptance Criteria
- JSON payloads are valid UTF-8 JSON objects.
- Typed values preserve Int/Bool where applicable instead of always stringifying.

### REQ-aps-cli-011

Commands that touch FileState SHALL resolve the state directory as `--state-dir` (accepted
before the subcommand or on the subcommand), then `APS_HOME`, then `~/.aps`. A subcommand
`--state-dir` wins over a peeled root `--state-dir`.

Acceptance Criteria
- `aps --state-dir PATH get note` uses PATH.
- `aps get note --state-dir PATH` still works.
- Subcommand `--state-dir` overrides a root `--state-dir` when both are present.
- When neither is set, FileState lands under `~/.aps`.

### REQ-aps-cli-012

`watch` SHALL support `--count`, `--timeout`, and `--jsonl`.

Acceptance Criteria
- `--count` stops after that many printed values including the initial value.
- `--timeout` stops after the given seconds.
- `--jsonl` emits one JSON object per line.

### REQ-aps-cli-013

The CLI `--version` string SHALL be `1.1.0`.

Acceptance Criteria
- `aps --version` prints `1.1.0`.
- `aps schema` `cliVersion` equals `1.1.0`.

### REQ-aps-cli-014

`aps stats` SHALL expose the process-local `DemoStats` ObservedDependency, including optional `--watch` with `--count` / `--timeout`.

Acceptance Criteria
- After `aps set counter 3` in the same process, `aps stats` reports last key `counter`.
- `aps stats --json` includes `mutationCount` and `lastMutatedKey`.
- `aps stats --watch --count 1` exits after printing the initial snapshot.



### REQ-aps-cli-015

Superseded by REQ-aps-cli-020 (encrypted-file secret store; issue #35). The Keychain-backed SecureState demo was removed because ad-hoc CLI signatures cannot earn durable Keychain trust.

### REQ-aps-cli-016

`profileName` SHALL read and write `ProfileDocument.name` through an AppState `Slice` over `profile`.

Acceptance Criteria
- `aps set profileName X` updates the parent `profile` document name on disk.
- `aps get profileName` returns the current parent name field.
- `aps keys` lists `profileName` with storage `Slice`.

### REQ-aps-cli-017

When a FileState file for `note`, `profile`, or `profileName` exists but is undecodable, `aps get` / `aps watch` SHALL fail with `corruptState` and exit code 65; `watch --jsonl` SHALL emit one error event before exiting. Missing files still resolve to initials. README SHALL document single-writer / last-writer-wins semantics.

Acceptance Criteria
- Torn `note.json` / `profile.json` never surfaces as the AppState initial value on the direct disk path.
- Exit code is 65 (`EX_DATAERR`) for `corruptState`.
- README documents the multi-process FileState contract.

### REQ-aps-cli-018

The repository SHALL provide a PowerShell smoke script with the same behavioral coverage as `Scripts/smoke.sh` for FileState / StoredState / keys / stats, and CI SHALL run `swift test` plus that smoke script on `windows-latest`.

Acceptance Criteria
- `Scripts/smoke.ps1` exercises flag/note/profile persistence, reset, dump, watch, stats, and invalid counter rejection.
- `.github/workflows/windows-smoke.yml` runs `swift test` then `Scripts/smoke.ps1` on `windows-latest` (Swift 6.3.1+).
- `APS_HOME` resolution tests mutate the process environment with a portable helper (not POSIX-only `setenv`).
- `specs/aps-cli/testing.md` and README document the Windows test + smoke path.


### REQ-aps-cli-020

The `secret` key SHALL be backed by an encrypted-file secret store under the
state root (ephemeral X25519 + HKDF + ChaCha20-Poly1305 via swift-crypto), with
zero interactive prompts in key-file mode and passphrase mode via
`APS_SECRET_PASSPHRASE`. When `secret.enc` already exists, `set` SHALL unlock
with the current recipient key before rewriting; unlock failure SHALL leave the
file unchanged and surface `APSError.secretUnlockFailed`. Passphrase vs key-file
mode remains stateful: a fresh or reset store seals with whichever recipient is
active on first write.

The encrypted-file SecretStore SHALL serialize fresh `set` key creation,
sealing, atomic envelope persistence, and read-back verification through
`secret.store.lock`. Every repair-capable key load for get, set, or watch SHALL
use that same lock. Invalid key material SHALL never be deleted or replaced:
fresh writes map it to `persistenceFailed`, while existing-envelope unlock maps
it to `secretUnlockFailed`. Passphrase-mode writes SHALL ignore stale
`secret.key` paths. Fresh key-creation disk failures SHALL remain
`persistenceFailed`. When an envelope exists, unlock paths SHALL NOT create or
truncate `secret.key`.

On POSIX, SecretStore SHALL canonicalize a symlinked state root once, preserve
safe owned root modes such as `0755`, and reject group- or other-writable roots
without changing their permissions. Encrypted watch SHALL reload and revalidate
key-file recipients for each changed snapshot while retaining passphrase state.
CLI get SHALL perform one encrypted read, and successful encrypted set output
SHALL not perform a redundant post-commit decrypt.

Acceptance Criteria
- `secret` round-trips set/get/reset with ciphertext at rest in `secret.enc`;
  POSIX key files use exact mode `0600`.
- No Security.framework/Keychain imports; works on macOS, Linux, and Windows.
- Wrong passphrase on `get` fails with `APSError.secretUnlockFailed`; corrupt envelope fails with `APSError.decodingFailed`.
- Wrong passphrase on `set` against an existing envelope fails with `secretUnlockFailed` and does not change ciphertext.
- Passphrase entry is env-var based; an optional TTY getpass prompt exists when `APS_SECRET_USE_PASSPHRASE=1`.
- Fresh and parallel SecretStore SET operations remain serialized and leave a decryptable envelope.
- Invalid stale key material is preserved byte-for-byte with a stable
  operation-specific error.
- Existing-envelope persistence failures remain `persistenceFailed`; invalid keys surface `secretUnlockFailed`.
- Fresh key-creation write failures remain `persistenceFailed`; unlock never truncates an existing key path.

### REQ-aps-cli-021

`aps key add|remove|list` SHALL mutate or list the state-root `schema.json` registry with stable error codes `schema_invalid` (65), `unknown_key` (64), and `schema_conflict` (64).

Acceptance Criteria
- `aps key add` persists a new entry; without `--force`, a duplicate name fails with `schema_conflict`.
- `aps key remove` drops the entry; `--purge` deletes FileState/EncryptedFile data when present.
- `aps key list` matches the inventory from `aps keys`.

### REQ-aps-cli-022

On first use of a state root, aps SHALL materialize a default `schema.json` seed matching the DemoKey inventory; subsequent commands resolve keys by string name from that registry.

Acceptance Criteria
- A fresh `--state-dir` gains `schema.json` after the first keys/get/set/schema call.
- Unknown names fail with `unknown_key` (exit 64).
- Invalid on-disk schema fails with `schema_invalid` (exit 65).

### REQ-aps-cli-023

`aps reset --all` SHALL restore only DemoKey seed keys. `aps reset --registered` SHALL restore every key in the active `schema.json` registry. Passing both, or a key with either flag, SHALL fail with a validation error.

Acceptance Criteria
- After `key add` + `set`, `reset --all` leaves the user key value unchanged.
- `reset --registered` restores that user key to its initial value.
- JSON payloads use `"reset":"all"` for `--all` and `"reset":"registered"` for `--registered`.

### REQ-aps-cli-024

`aps schema` SHALL advertise root-or-subcommand `--state-dir`, reset
`--registered`, repeatable key-add `--field NAME=TYPE`, bulk reset report
payloads, and integer `schemaVersion` 6 for this contract shape.

Acceptance Criteria
- `aps schema` emits `"schemaVersion":6`.
- The `reset` command entry lists flags including `--registered`.
- The `key add` command entry lists flags including `--field`.

### REQ-aps-cli-019

`aps schema` SHALL emit one cacheable JSON document describing the CLI
contract: cliVersion, integer schemaVersion (bumped when the document shape
changes), state-root precedence, live registered keys, `userSchema` meta
(formatVersion, keyCount, hash), commands, payload shapes, and the error table.

Acceptance Criteria
- Output is valid JSON with top-level integer `schemaVersion` equal to 6 after
  this change.
- Keys cover every entry in the active `schema.json`; commands cover every
  subcommand including `key`.
- `cliVersion` equals `aps --version`.
- `userSchema.hash` changes when the registry changes.
- `userSchema.keyCount` equals both the active registry key count and the
  number of projected key contracts.
- Live values stay in `dump`.

### REQ-aps-cli-025

The shared file lock helper SHALL support exclusive locks for each state file
used by a read-modify-write operation, while preserving the existing schema
lock API.

Acceptance Criteria
- Schema mutations continue to use `schema.json.lock`.
- FileState and Slice writes can serialize on `profile.json.lock`.

### REQ-aps-cli-026

When no `secret.enc` envelope exists, a fresh SecretStore SET SHALL create key
material only when `secret.key` is absent. Invalid existing key material SHALL
remain unchanged and fail as `persistenceFailed`. The fresh SET operation SHALL
remain serialized by `secret.store.lock`.

Acceptance Criteria
- A partial, malformed, or invalid `secret.key` is never removed or replaced.
- An absent key path is exclusively created with a valid private key.
- Invalid material without an envelope fails as `persistenceFailed`; invalid
  material with an envelope fails as `secretUnlockFailed`.

### REQ-aps-cli-027

Persistent FileState and EncryptedFile schema paths SHALL be portable relative
regular-file paths contained beneath the canonical state root. APS SHALL reject
root aliases, absolute or traversing paths, reserved internal paths,
directories, symbolic links, special files, and portable path collisions.

Acceptance Criteria
- `.` and `./` cannot be registered and cannot delete the state root.
- APS internal schema, key, and lock paths cannot be registered.
- Paths that collide case-insensitively cannot coexist in one schema.
- Valid nested relative paths continue to support get, set, reset, and purge.
- A rejected reset or purge preserves the target and returns a nonzero error.

### REQ-aps-cli-028

Every CLI operation accepting a registered key name SHALL derive runtime
behavior and machine output from that key's current `SchemaKeyEntry`, including
when the name belongs to the default seed inventory. Name-based `DemoKey`
dispatch SHALL NOT override the live registry.

Acceptance Criteria
- Forced seed replacements control get, set, reset, watch, dump, and typed
  machine output.
- `reset --all` targets registered seed names through their current entries and
  does not recreate removed seed names.
- Storage or path replacement does not implicitly migrate or delete old data.
- Default seeded behavior remains compatible after schema materialization.

### REQ-aps-cli-029

Reset and purge commands SHALL report every detected persistence failure
through the stable error contract and SHALL NOT emit success output after a
failure. Bulk reset SHALL fail fast in schema order and report successfully
reset, first-failed, and not-attempted keys.

Acceptance Criteria
- Wrong-kind, deletion, replacement, postcondition, and rollback failures exit
  nonzero with stable machine codes.
- Machine failures keep stdout empty and emit one structured error on stderr.
- A partial bulk result contains `reset`, `failed`, and `notAttempted`.
- Mutation statistics count only keys whose reset postcondition succeeded.
- Documentation limits transaction guarantees to errors detected before API
  return and does not claim crash or power-loss atomicity.

### REQ-aps-cli-031

Every key-file load that may repair or create key material SHALL serialize
through `secret.store.lock`, including get, set, and changed watch snapshots.
Key-file watch SHALL reload and revalidate the key for every changed envelope;
unchanged polls SHALL perform no recipient work.

On POSIX, SecretStore SHALL canonicalize the configured state root once,
preserve safe owned directory modes such as searchable `0300` and shared-read
`0755`, and reject group- or other-writable roots without changing their
permissions. Permission-repair failures SHALL return
`insecure_secret_key_file`; unrelated I/O failures retain their persistence
mapping.

CLI get SHALL perform one encrypted read. After SecretStore successfully
persists and decrypt-verifies an encrypted set, CLI output SHALL use the
verified submitted value without another decrypt.

The v2 KDF wire keys remain `algorithm`, `salt`, `rounds`, `blockSize`,
`parallelism`, and `outputByteCount`. Unsupported versions or recipient modes
SHALL return `unsupported_secret_envelope`; malformed fields and KDF
combinations SHALL return `decoding_failed`. Invalid existing key material
SHALL never be truncated, replaced, or deleted.

Acceptance Criteria
- Get, set, and watch use one store lock for repair-capable key access.
- Safe POSIX root modes are preserved; writable roots fail closed unchanged;
  symlinked roots round-trip through one canonical target.
- Changed key-file watch snapshots support coherent key/envelope rotation and
  revalidate key privacy.
- CLI get performs one decrypt and encrypted set output performs no
  post-commit decrypt.
- The full 235-test local lane and every hosted platform gate pass.

### REQ-aps-cli-032

A missing or null version 2 `recipientMode` SHALL return `decoding_failed`
before KDF work. An unrecognized non-null recipient mode SHALL return
`unsupported_secret_envelope`.

POSIX key-file load and create SHALL revalidate exact `0600` mode through both
descriptor and path immediately before accepting key material. A registered
encrypted watch SHALL pin the canonical state-root target selected by its
initial store for the watch lifetime while continuing descendant validation
beneath that root.

Acceptance Criteria
- Missing and null version 2 modes perform zero KDF work and fail as malformed.
- Unknown non-null recipient modes retain the unsupported-envelope error.
- Post-read POSIX permission widening is rejected with exact bytes preserved.
- Retargeting the configured state-root symlink cannot redirect a running
  registered encrypted watch.
- The full 238-test local lane and every hosted platform gate pass.

### REQ-aps-cli-033

APS SHALL preserve registered object values as recursive structural JSON in
every machine-output path. Get, set, dump, watch, and reset SHALL retain all
null, boolean, integer, finite floating-point, string, array, and object values
without a domain-model coercion or JSON string envelope.

`aps key add` SHALL accept repeatable `--field NAME=TYPE` declarations for
object shapes. It SHALL reject malformed, duplicate, unsupported, or
non-object field declarations before mutating `schema.json`. Object initials
SHALL match their declared type and every declared shape field. Undeclared
object fields MAY be retained.

Slice entries SHALL name a declared field on an existing FileState object
parent. The parent field type, Slice type, and typed Slice initial SHALL agree.
Invalid or formerly unshaped Slice definitions SHALL fail as `schema_invalid`
before storage mutation.

`aps schema` SHALL publish `schemaVersion` 6 and
`userSchema.keyCount`. `keyCount` SHALL equal both the active registry key
count and the number of projected key contracts.

Acceptance Criteria
- Arbitrary nested objects with profile-like and extra fields round-trip through
  all machine outputs without field loss or stringification.
- Recursive JSON tests cover null, Bool, Int, finite Double, String, arrays,
  and nested objects.
- `key add --field name=String --field retries=Int` persists a usable shape;
  malformed and duplicate declarations fail without changing the registry.
- Schema loading rejects initial/type/shape mismatches and invalid Slice
  parent, field, type, or initial combinations.
- The default seven-key schema and profile/profileName behavior remain
  compatible.
- `aps schema` reports version 6 and a `keyCount` equal to `keys.count`.

### REQ-aps-cli-034

APS machine output SHALL preserve recursive JSON structure and numeric value.
Equivalent integral JSON spellings such as `1`, `1.0`, and `1e0` MAY
canonicalize to an integer because JSON and Foundation Codable do not expose a
stable lexical numeric subtype.

Schema validation SHALL reject nonfinite doubles at every recursive array or
object depth, including undeclared fields preserved by an open object shape.
Schema version 6 SHALL advertise null, boolean, integer, finite number, string,
array, and object for every recursive value-bearing payload.

Acceptance Criteria
- Integral numeric spellings have documented canonical semantics while
  nonintegral finite values retain their numeric value.
- Nested infinity and NaN values fail schema validation.
- KeyValuePayload, WatchEvent, and ResetPayload advertise the complete
  recursive JSON kind set.
- Focused regressions and the full quality lane pass.

### REQ-aps-cli-035

Dynamic Bool parsing SHALL accept the same tokens as the central Bool parser,
including `y` and `n`. Object Slice schemas SHALL require a parent initial that
satisfies every nested Slice shape and identical shapes for sibling object
Slices targeting one parent field. Direct parent writes SHALL satisfy every
targeting Slice constraint before mutation. Canonical terminology SHALL list
every public recursive SchemaJSON case. Recursive JSON decoding SHALL reject
integral numeric values that cannot be represented exactly as native Int values.

Acceptance Criteria
- Dynamic Bool values accept `y`, `Y`, `n`, and `N`.
- Invalid parent initials and incompatible sibling Slice shapes are rejected.
- Invalid direct parent writes fail without creating or changing storage.
- Canonical terminology includes array and object cases.
- Out-of-range integral JSON is rejected instead of rounded through Double.
- Focused regressions and the full quality lane pass.

### REQ-aps-cli-036

Before publishing or backfilling release artifacts, the release workflow SHALL
resolve the selected semantic tag to one exact commit and require that commit
to carry an Attest record with passing tests and a valid Ed25519 signature from
the pinned `human:leif` signer identity. The commit SHALL be reachable from the
default branch, including when it is a merge commit. All test and build
checkouts SHALL use that resolved SHA, and publication SHALL fail if the tag no
longer resolves to it. Manual backfills SHALL use current default-branch gate
and policy files so historical tags need not contain them. The publication job
SHALL require the GitHub `release` Environment. Ordinary pull request workflows
SHALL remain usable without the release key.

Acceptance Criteria
- A missing note, failed-test evidence, unsigned evidence, an invalid signature,
  or a signature from an untrusted key blocks publication.
- Valid signed passing-test evidence from the pinned signer passes.
- Tag pushes and manual backfills use the same gate.
- Manual backfills execute trusted control-plane files from the current default
  branch while gating and building the historical tag commit.
- SemVer-invalid tags are rejected and Attest verifies only the selected commit,
  including for merge commits.
- The selected SHA is used by tests and every platform build.
- Release-critical Actions are pinned by full commit SHA and checkout
  credentials are not persisted.
- The tag binding is checked immediately before and after artifact attachment.
- Repository operations document the required protected `v*` tag ruleset,
  `release` Environment reviewer, external administrator trust, and recovery
  from a failed post-publication check.

### REQ-aps-cli-037

APS release preparation SHALL synchronize one reviewed semantic version across
runtime help, schema output, tests, smoke scripts, canonical requirements,
plugin metadata, README, release documentation, and the product site. A
deterministic repository check SHALL fail when any declared version surface
drifts.

The Linux release artifact SHALL be
`aps-linux-x86_64-portable.tar.gz`. Its executable SHALL contain
`$ORIGIN/lib`, and its sibling `lib/` directory SHALL contain the Swift runtime
libraries needed to run without an installed Swift toolchain. Release,
installer, checksum, and Homebrew contracts SHALL use the same asset name and
archive layout. Homebrew SHALL preserve the executable beside `lib/` under
`libexec` and expose a wrapper from `bin`.

The product site SHALL consume the commit-pinned `0xLeif/0x` contribution
fork, credit `tofu-ux/0x` upstream, implement its dark-first no-flash theme
contract, and retain aps-specific Swift state and command examples.

Acceptance Criteria
- Every declared product-version surface reports 1.1.0.
- A deliberate version mismatch fails the version-contract test.
- The archived Linux executable passes runtime-path inspection, checksum and
  installer extraction tests, and execution in Linux without Swift installed.
- Formula generation emits matching portable URLs, checksums, and a
  `libexec` bundle install.
- The site uses upstream 0x tokens and components, exposes an accessible
  theme toggle, and passes both hosting builds and rendered-output tests.
- The release dry run targets v1.1.0 without unexpected edits.
