# Release readiness

Status: **v1.1.0 released on 2026-07-29**

This document is the completed safety-release audit. The implementation,
release authentication recovery, checksum repair, signed publication, and
Homebrew convergence are archived in SpecSync.

Target release line: **1.1.0**. This release added a reusable installer Action, portable Linux
packaging, dynamic schema behavior, concurrency fixes, and watch improvements.

## What is already strong

- The fledge verification lane passes all eight steps.
- 266 Swift tests pass, including recursive structural JSON, strict Slice schema,
  transactional reset, secret hardening, and four-worker isolation regressions.
- macOS, Ubuntu, Linux smoke, Windows smoke, and Trust workflows run on main.
- Existing merged SpecSync changes are archived; release provenance remains
  active until accepted.
- Human, JSON, and JSONL output contracts are broadly exercised.

Measured in-process source line coverage is 53.42%. Subprocess CLI tests are not attributed back to the instrumented test process, so that number understates command-path coverage. It still shows that registry, dynamic storage, command dispatch, and termination behavior need more direct tests.

## Closed for v1.1.0

### 1. Make schema paths safe by construction

Implemented for v1.1.0 by [#111](https://github.com/0xLeif/aps-cli/issues/111). Persistent paths are lexically portable, canonicalized beneath the state root, collision-checked across the complete schema, and revalidated against the filesystem before every operation. Directories, special files, symbolic links, reserved APS files, and root or traversal aliases are rejected. Reset and purge delete only a verified regular-file leaf. Unit and cross-platform smoke regressions preserve a state-root sentinel during the original `"."` attack.

### 2. Make the registry authoritative

Implemented for v1.1.0 by [#112](https://github.com/0xLeif/aps-cli/issues/112). Every registered name, including seed names replaced with `key add --force`, now uses its current schema entry for type, storage, path, initial value, Slice metadata, watch behavior, dump behavior, and output typing. Registry snapshots are coherent and legacy flag fallback is limited to the unchanged default seed definition.

### 3. Enforce recursive object and Slice typing

Implemented for v1.1.0 by
[#114](https://github.com/0xLeif/aps-cli/issues/114). Recursive structural JSON
values, open object shapes whose declared fields are required and type-checked,
preservation of undeclared fields, repeatable `--field NAME=TYPE`
declarations, strict matching Slice fields, live `userSchema.keyCount`, and
static `schemaVersion` 6 are covered by unit, smoke, and hosted regressions.

### 4. Make reset and purge report the truth

Implemented for v1.1.0 by
[#113](https://github.com/0xLeif/aps-cli/issues/113). Reset APIs throw,
destructive filesystem operations stage recoverable leaves before verification,
FileState reset atomically overwrites its initial value under the storage lock,
StoredState restores its prior raw objects after detected replacement failure,
and SecretStore reset removes only the envelope under `secret.store.lock`.

Schema removal plus purge holds the schema lock through storage deletion and
restores the original schema on a detected purge failure. Registered writers
resolve and persist under that same schema lock, so stale writers cannot
recreate purged data. This guarantee is transactional for detected errors, not
for process crashes or power loss. Bulk reset remains deterministic and
fail-fast while returning an explicit report of reset, failed, and
not-attempted keys; mutation stats count only verified successes.

### 5. Repair Linux and Homebrew distribution

Implemented for v1.1.0 under
[#115](https://github.com/0xLeif/aps-cli/issues/115) and
[#116](https://github.com/0xLeif/aps-cli/issues/116). The release build now
applies `$ORIGIN/lib` before copying the executable, inspects that runtime path,
runs the checksum and installer extraction path against the exact archive, and
executes the bundle in a clean Ubuntu container without Swift. Release,
installer, and formula automation agree on
`aps-linux-x86_64-portable.tar.gz`. The reviewed formula template installs the
Linux bundle under `libexec` and exposes a wrapper from `bin`, preserving the
executable beside its Swift runtime libraries.

### 6. Make versioning atomic

Implemented for v1.1.0 under
[#117](https://github.com/0xLeif/aps-cli/issues/117). `VERSION` plus
`Scripts/prepare-version.py` update or verify runtime help, schema output,
smoke scripts, tests, specs, README, plugin metadata, release documentation,
and the product site as one reviewed operation. The verification lane fails on
drift. The final release uses `fledge release minor --no-bump` from clean
main.

### 7. Harden passphrase secrets

Implemented for v1.1.0 by
[#118](https://github.com/0xLeif/aps-cli/issues/118). Every new encrypted
envelope is strict v2 and records `recipientMode`. Passphrase writes use a
fresh random 16-byte salt and the public CryptoExtras scrypt implementation at
`N=131072`, `r=8`, `p=1`, with 32 output bytes and approximately 128 MiB of
memory per derivation. KDF metadata and cryptographic field bounds are checked
before scrypt runs.

Legacy key-file envelopes remain readable and upgrade on their next successful
set. A successfully unlocked legacy passphrase envelope migrates once under
`secret.store.lock`; wrong credentials do not migrate, and detected migration
failure restores and verifies the exact legacy bytes. Recipient-mode mismatch
never falls back or creates another key.

Passphrase derivation is cached only within one SecretStore operation.
Encrypted watch compares complete envelope bytes before decryption, so unchanged
polls do no KDF work. POSIX key-file access enforces current-user ownership,
regular-file type, no-follow handles, and exact `0600`. Windows handle checks
reject reparse and wrong-kind objects, require current-user ownership, and
enforce a protected private DACL. Unsafe paths are not replaced or truncated.

The stable error contract now distinguishes unsupported envelopes
(`unsupported_secret_envelope`, exit 65), wrong credentials or mode
(`secret_unlock_failed`, exit 69), and unprovable key-file privacy
(`insecure_secret_key_file`, exit 77). Persistence and migration restoration
failures retain `persistence_failed` and `rollback_failed` at exit 73.
apple/swift-crypto is constrained to `4.0.0..<4.4.0` because 4.4+ raises its
Swift tools floor to 6.1 while aps retains Swift 6.0.

### 8. Enforce release provenance

Implemented for v1.1.0 by
[#119](https://github.com/0xLeif/aps-cli/issues/119). Pull request provenance
remains soft so contributors do not need the release key. The artifact
publication gate uses `.attest-release.json`: the exact selected tag commit must
have passing-test evidence with a valid Ed25519 signature from the pinned
`human:leif` identity.

Tag pushes and manual backfills share the gate. Tests and builds use the one
resolved commit SHA, and the publication job refreshes and compares the tag
binding immediately before upload. The deterministic contract test covers
missing notes, failed tests, unsigned records, invalid signatures, untrusted
keys, valid signed evidence, and moved tags. Backup, recovery, compromise, and
rotation procedures are in [release provenance](release-provenance.md).
The protected `v*` tag ruleset and `release` Environment remain operator-owned
GitHub settings. Confirm them immediately before signing and pushing the tag.

## Release proof

The v1.1.0 release completed this procedure. Keep it as the reproducible
operator checklist for a future release:

1. Run `Scripts/prepare-version.py --check`,
   `fledge lanes run verify`, and
   `fledge trust verify --range origin/main...HEAD`.
2. Sign the exact candidate commit with passing-test evidence and verify
   `.attest-release.json`.
3. Push `refs/notes/attest` before the tag.
4. Require every main check to finish successfully.
5. Run `fledge release minor --no-bump --dry-run` from a clean checkout and
   confirm it targets v1.1.0 without edits.
6. Publish the candidate artifacts.
7. Verify every checksum sidecar.
8. Execute both macOS binaries.
9. Extract and execute the Linux bundle without a Swift toolchain.
10. Install the final formula on macOS and Linux.
11. Run a separate workflow using `0xLeif/aps-cli@<tag>` and exercise a real command.
12. Confirm `aps --version`, `aps schema`, plugin version, release tag, and documentation all agree.

## Quality work after the safety release

- Enforce explicit access control, descriptive generic names, line length, and the production `try!` prohibition in CI.
- Add the explicit StrictConcurrency package setting required by repository conventions.
- Split command parsing, persistence, watching, and serialization into focused files.
- Publish a Windows asset and add installer parity when Windows distribution becomes a product promise.
- Decide whether process-local `State` and `stats` need a session mode or should remain explicitly documented dogfood demonstrations.
