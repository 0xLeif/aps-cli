# Release readiness

Status: **not ready to tag**

Audited commit: `5a05e38a85975c4fba1aec2f916a1ab1764d52b8`

Target release line: **1.1.0**, because the work since 1.0.0 adds a reusable installer Action, portable Linux packaging, dynamic schema behavior, concurrency fixes, and watch improvements.

## What is already strong

- The fledge verification lane passes all seven steps.
- 156 Swift tests pass, including four-worker isolation.
- SpecSync passes with 2 specs, 0 errors, and 0 warnings.
- macOS, Ubuntu, Linux smoke, Windows smoke, and Trust workflows run on main.
- The repository has no active SpecSync changes after the latest archive housekeeping.
- Human, JSON, and JSONL output contracts are broadly exercised.

Measured in-process source line coverage is 53.42%. Subprocess CLI tests are not attributed back to the instrumented test process, so that number understates command-path coverage. It still shows that registry, dynamic storage, command dispatch, and termination behavior need more direct tests.

## Must close before the next tag

### 1. Make schema paths safe by construction

Implemented for v1.1.0 by [#111](https://github.com/0xLeif/aps-cli/issues/111). Persistent paths are lexically portable, canonicalized beneath the state root, collision-checked across the complete schema, and revalidated against the filesystem before every operation. Directories, special files, symbolic links, reserved APS files, and root or traversal aliases are rejected. Reset and purge delete only a verified regular-file leaf. Unit and cross-platform smoke regressions preserve a state-root sentinel during the original `"."` attack.

### 2. Make the registry authoritative

Implemented for v1.1.0 by [#112](https://github.com/0xLeif/aps-cli/issues/112). Every registered name, including seed names replaced with `key add --force`, now uses its current schema entry for type, storage, path, initial value, Slice metadata, watch behavior, dump behavior, and output typing. Registry snapshots are coherent and legacy flag fallback is limited to the unchanged default seed definition.

Recursive arbitrary object values remain tracked separately and do not weaken authority over the object shapes currently supported by the schema.

### 3. Make reset and purge report the truth

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

### 4. Repair Linux and Homebrew distribution

The release workflow currently copies the Linux binary before rebuilding it with the portable `$ORIGIN/lib` rpath. The post-release formula workflow also requests the old `aps-linux-x86_64.sha256` while releases now publish `aps-linux-x86_64-portable.tar.gz`.

Required outcome:

- build the rpath-enabled executable before copying it into the archive;
- execute the extracted archive on a clean Linux host without Swift;
- update the Homebrew formula to preserve the executable and bundled libraries together;
- assert that release, installer, and formula asset names agree.

### 5. Make versioning atomic

The version appears in Swift source, schema output, smoke scripts, tests, specs, README, and `plugin.toml`. The current fledge release plan only bumps the plugin manifest.

Required outcome:

- one reviewed version preparation change updates every contract;
- smoke and schema tests prove the new version;
- the final release uses `fledge release ... --no-bump` from clean main.

### 6. Harden passphrase secrets

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

## Release-candidate proof

After the blockers merge:

1. Run `fledge lanes run verify` and `fledge trust verify`.
2. Require every main check to finish successfully.
3. Run the release dry run from a clean checkout and inspect version plus notes.
4. Publish the candidate artifacts.
5. Verify every checksum sidecar.
6. Execute both macOS binaries.
7. Extract and execute the Linux bundle without a Swift toolchain.
8. Install the final formula on macOS and Linux.
9. Run a separate workflow using `0xLeif/aps-cli@<tag>` and exercise a real command.
10. Confirm `aps --version`, `aps schema`, plugin version, release tag, and documentation all agree.

## Quality work after the safety release

- Enforce explicit access control, descriptive generic names, line length, and the production `try!` prohibition in CI.
- Add the explicit StrictConcurrency package setting required by repository conventions.
- Split command parsing, persistence, watching, and serialization into focused files.
- Pin release-critical GitHub Actions by commit.
- Turn attestation, test, and signature requirements on, or narrow the documented provenance claim.
- Publish a Windows asset and add installer parity when Windows distribution becomes a product promise.
- Decide whether process-local `State` and `stats` need a session mode or should remain explicitly documented dogfood demonstrations.
