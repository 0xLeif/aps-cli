# Release readiness

Status: **not ready to tag**

Audited commit: `5a05e38a85975c4fba1aec2f916a1ab1764d52b8`

Target release line: **1.1.0**, because the work since 1.0.0 adds a reusable installer Action, portable Linux packaging, dynamic schema behavior, concurrency fixes, and watch improvements.

## What is already strong

- The fledge verification lane passes all seven steps.
- 78 Swift tests pass, including four-worker isolation.
- SpecSync passes with 2 specs, 0 errors, and 0 warnings.
- macOS, Ubuntu, Linux smoke, Windows smoke, and Trust workflows run on main.
- The repository has no active SpecSync changes after the latest archive housekeeping.
- Human, JSON, and JSONL output contracts are broadly exercised.

Measured in-process source line coverage is 53.42%. Subprocess CLI tests are not attributed back to the instrumented test process, so that number understates command-path coverage. It still shows that registry, dynamic storage, command dispatch, and termination behavior need more direct tests.

## Must close before the next tag

### 1. Make schema paths safe by construction

Current validation accepts `"."`, `"./"`, directories, reserved internal files, shared paths, and paths containing symlink escapes. A reproduced `EncryptedFile` key with path `"."`, followed by `key remove --purge`, deleted the entire state root.

Required outcome:

- canonicalize and prove containment under the state root;
- reject the root itself, directories, reserved files, and symlink traversal;
- reject storage-path collisions across registered keys;
- delete only a verified regular leaf file;
- cover every destructive path with adversarial subprocess tests.

### 2. Make the registry authoritative

Built-in names still select hard-coded adapters even after `key add --force` changes their schema entries. Either reserve built-in entries and make them immutable, or route every name through the same registry adapters.

Required outcome:

- one source of truth for type, storage, path, initial value, and output shape;
- strict validation for initial values, object shapes, and Slice targets;
- recursive JSON values for arbitrary dynamic objects;
- `userSchema.keyCount` included as required by the published contract.

### 3. Make reset and purge report the truth

Some persistence deletion failures are discarded with `try?`, allowing reset to print success while state remains.

Required outcome:

- throwing reset APIs;
- lock and transaction semantics for schema removal plus purge;
- verified postconditions;
- atomic or explicit per-key results for bulk reset.

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

Passphrase mode derives its X25519 key using HKDF-SHA256 with fixed context. HKDF is not a password-hardening KDF and permits inexpensive offline guessing of low-entropy passphrases.

Required outcome:

- version the encrypted envelope;
- use Argon2id or scrypt with a random per-store salt and documented parameters;
- migrate or clearly reject legacy passphrase envelopes;
- validate existing key-file ownership, type, and permissions;
- propagate and verify secret reset failures.

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
