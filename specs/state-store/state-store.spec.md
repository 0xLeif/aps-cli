---
module: state-store
version: 41
status: active
files:
  - Sources/aps/StateStore.swift
  - Sources/aps/StateStore+Registry.swift
  - Sources/aps/WatchPolling.swift
  - Sources/aps/DemoState.swift
  - Sources/aps/Dependencies.swift
  - Sources/aps/DynamicKeyStorage.swift
  - Sources/aps/SchemaStoragePath.swift
db_tables: []
depends_on: []
---

# State Store

## Purpose

`StateStore` is the AppState-facing service used by the CLI. It reads and writes
all string-key registry entries through `DynamicKeyStorage`, including default
seed names, injects real dependencies with `@AppDependency`, and provides dump,
watch, and reset helpers suitable for non-UI use. Direct `DemoKey` adapters
delegate writes and resets through the same schema-locked registry transaction
and synchronize the default AppState dogfood surface before releasing the lock.

## Public API

| Export | Description |
|--------|-------------|
| `StateStore` | MainActor facade over registry-backed AppState keys. |
| `init` | Loads clock/jsonCoding/stats dependencies without forcing `~/.aps`. |
| `get` | Returns the current string rendering for a demo or registry key. |
| `set` | Schema-locked demo or registry write with one stats mutation. |
| `reset` | Schema-locked reset that verifies storage before recording stats. |
| `resetAll` | Deterministic fail-fast reset of every currently registered demo seed name. |
| `resetAllRegistered` | Deterministic fail-fast reset of every active registry key with an explicit report. |
| `dump` | JSON snapshot of demo seed adapters (pretty on TTY, compact when piped). |
| `dumpRegistered` | JSON snapshot of every registry key. |
| `watchBlocking` | Direct DemoKey observation or uniform string-entry polling, bounded by an optional deadline. |
| `watchStatsBlocking` | Combine + polling watch loop for ObservedDependency stats, bounded by an optional deadline. |
| `statsSnapshot` | Immutable view of DemoStats counters. |
| `resetStats` | Clears process-local DemoStats counters. |
| `loadSchema` | Load or materialize schema.json for the active state root. |
| `resolve` | Resolve a SchemaKeyEntry by name or throw `unknownKey`. |
| `addKey` | Persist a new or forced-replaced schema entry under SchemaFileLock. |
| `removeKey` | Remove a schema entry and optional persisted data in one detected-error transaction under SchemaFileLock. |
| `stateRoot` | Active FileState / schema.json directory. |
| `APSPaths` | State-root resolution; peels root `--state-dir` before ArgumentParser. |
| `peelRootStateDir` | Removes leading `--state-dir` tokens from argv before the subcommand. |
| `setRootStateDirOverride` | Stores a peeled root `--state-dir` for `boot`. |
| `rootStateDirOverride` | Peeled root override consulted when resolving the state directory. |
| `configure` | Apply resolved path (subcommand > root override > APS_HOME > ~/.aps) to FileManager.defaultFileStatePath. |
| `defaultFileStateDirectory` | `~/.aps` fallback path. |
| `profileDocument` | Typed profile FileState accessor. |
| `profileName` | Slice accessor for ProfileDocument.name. |
| `readNoteFromDisk` | Direct `note.json` read requiring a present decodable file. |
| `readNoteFromDiskIfPresent` | Optional `note.json` read; throws `corruptState` if torn. |
| `readProfileFromDisk` | Direct `profile.json` read requiring a present decodable file. |
| `readProfileFromDiskIfPresent` | Optional `profile.json` read; throws `corruptState` if torn. |
| `requireDecodableDiskState` | Loud-fail helper for CLI get/watch on FileState keys. |
| `parseBool` | Bool token parser for flag values. |
| `APSClock` | Injected clock dependency protocol. |
| `now` | APSClock current instant. |
| `SystemAPSClock` | Date-backed clock. |
| `JSONCoding` | Shared encode helpers for dump output. |
| `encodePretty` | Pretty JSON encode helper. |
| `encodeAuto` | TTY-aware JSON encode helper (pretty on TTY, compact when piped). |
| `DemoStats` | ObservableObject mutation-stats dependency. |
| `mutationCount` | Number of recorded set/reset mutations. |
| `lastMutatedKey` | Raw key name of the latest mutation. |
| `recordMutation` | Increments counters for a string key name. |
| `reset` | Clears DemoStats counters. |
| `DemoStatsSnapshot` | Codable snapshot of DemoStats. |

## Invariants

1. All mutating AppState access happens on the main thread / MainActor.
2. Writing `flag` calls `UserDefaults.standard.synchronize()` so Linux flushes
   before process exit.
3. `dumpRegistered()` includes every key in the active schema.json plus an
   ISO-8601 timestamp.
4. `watchBlocking` emits the current value first, then subsequent distinct values.
5. A supplied polling deadline bounds the wait even when the configured interval is larger.
6. Dependencies are real services, not fake stubs used only for wiring demos.
7. `schema.json` write failures surface as `APSError.persistenceFailed`.
8. Schema RMW (add/remove/materialize-on-missing) is serialized by `SchemaFileLock`.
9. `SecretStore.set` never replaces an existing envelope without a successful unlock.
10. Every string-key operation uses the current resolved `SchemaKeyEntry`; a
    seed-name match does not select a compiled adapter.
11. The default Bool/StoredState flag can read JSON-encoded legacy
    `App/aps.flag` data only when `aps.user.flag` is absent; reset clears the
    legacy key before writing the current initial value.
12. FileState and Slice reset snapshot exact prior file bytes and atomically
    overwrite a nonnil initial value under the per-file lock, restoring absent
    or present state after detected verification failure. EncryptedFile reset
    holds `secret.store.lock`, deletes only the envelope, verifies absence, and
    preserves shared key material.
13. Schema removal with purge holds the schema lock through storage deletion.
    The candidate schema is reloaded and compared before destructive purge. A
    detected purge failure restores, reloads, and compares the original schema
    before the lock is released; rollback failure is reported distinctly.
14. Bulk reset runs in schema order, stops after the first failure, reports
    reset and not-attempted keys, and records stats only for verified successes
    after the outer schema lock is released.
15. The removal guarantee covers errors detected before return. It does not
    claim crash or power-loss atomicity.
16. Default adapter synchronization participates in single and bulk reset
    transactions. Failure restores the exact backing checkpoint and compiled
    adapter cache, reports no mutation for the failed key, and reports
    `rollbackFailed` if restoration cannot be proven. Bulk checkpoints are
    captured per key immediately before mutation.
17. A successfully unlocked legacy passphrase envelope migrates once under
    `secret.store.lock`; a wrong passphrase and a successfully rolled-back
    migration preserve the exact legacy bytes.
18. Legacy key-file envelopes read without mutation and upgrade to v2 only on
    the next successful set.
19. Passphrase derivation caching is scoped to one SecretStore operation and
    one validated salt. Encrypted watch compares complete envelope bytes before
    decryption and performs no KDF work for unchanged polls.
20. Key-file reads, repair, and creation use validated native handles. POSIX
    requires current-user ownership, regular-file type, no link following, and
    exact `0600`; Windows requires a current-user owner SID, non-reparse disk
    file, and protected private DACL.
21. Dynamic storage validates a value against its declared type and open object
    shape before mutation and after persistence reads. FileState object roots
    that are scalar, arrays, or shape-invalid surface as `corruptState`.
22. Object shapes require every declared field while preserving undeclared
    recursive JSON fields. Supported recursive values are null, Bool, Int,
    finite Double, String, array, and object.
23. Slice entries have typed initials and resolve only to explicitly declared,
    type-compatible fields on FileState object parents. Validation supports
    forward references and rejects invalid schemas before storage mutation.

## Behavioral Examples

```
Given a StateStore on a clean Application
When set(.counter, value: "7") then get(.counter)
Then the result is "7".
```

```
Given set(.flag, value: "true")
When a new process constructs StateStore and get(.flag)
Then the result is "true" (StoredState persistence after synchronize).
```

```
Given watchBlocking(.counter, shouldContinue: { seen.count < 2 })
When onChange receives "1" and sets counter to "2"
Then seen equals ["1", "2"].
```

```
Given dump() after set(.counter, value: "41") and set(.message, value: "hi")
When decoding the JSON
Then the default State entries expose the live AppState adapter values 41 and "hi",
preserve registry type and storage metadata, and include a timestamp field.
```

```
Given a FileState object with declared fields and additional recursive fields
When it is set and read through DynamicKeyStorage
Then declared fields are validated and all undeclared fields are preserved.
```

## Error Cases

- `set(.counter, value: "nope")` throws `APSError.invalidValue`.
- `set(.flag, value: "maybe")` throws `APSError.invalidValue`.
- JSONCoding encode failures surface as `APSError.encodingFailed` when UTF-8
  conversion fails. Profile JSON parse failures surface as `APSError.invalidValue`.
- Reset and purge persistence failures surface as `persistenceFailed`. If purge
  fails and schema restoration also fails, removal surfaces `rollbackFailed`.
- Unsupported envelope version or mode surfaces `unsupportedSecretEnvelope`.
  A malformed supported envelope surfaces `decodingFailed`.
- Existing-envelope credential, recipient-mode, or invalid recipient-key
  failures surface `secretUnlockFailed`.
- An unsafe key-file handle surfaces `insecureSecretKeyFile`; the path remains
  unchanged.

## Dependencies

- AppState (`Application`, `State`, `StoredState`, `FileState`, `@AppDependency`)
- SecretStore v2 recipient operations backed by apple/swift-crypto
  `4.0.0..<4.4.0` and public CryptoExtras scrypt
- Observation (`withObservationTracking`) for in-process watch delivery
- Foundation (`UserDefaults`, `RunLoop` on Apple, `Thread.sleep` elsewhere, `JSONEncoder`)

## Change Log

- 1: Initial StateStore / Application demo-state contract for the aps CLI.
- 2: Explicit export inventory for SpecSync active-contract checks.
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
| 2026-07-18 | CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review: Fix FileState watch cache and path isolation from review |
| 2026-07-18 | CHG-0001-adopt-corvidlabs-trust-and-establish-aps-module-contracts: Adopt CorvidLabs trust and establish aps module contracts |
| 2026-07-18 | CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review: Fix FileState watch cache and path isolation from review |
| 2026-07-18 | CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review: Fix FileState watch cache and path isolation from review |
| 2026-07-18 | CHG-0004-ship-aps-0-2-0-agent-ready-json-state-dir-watch-and-profile-filestate: Ship aps 0.2.0 agent-ready JSON state-dir watch and profile FileState |
| 2026-07-18 | CHG-0011-dogfood-observeddependency-demostats-for-issue-18: ObservedDependency DemoStats dogfood |
| 2026-07-18 | CHG-0012-dogfood-securestate-secret-keychain-demo-key: SecureState secret Keychain dogfood |
| 2026-07-18 | CHG-0013-dogfood-appstate-slice-via-profilename: Slice profileName dogfood |
| 2026-07-18 | CHG-0011-dogfood-observeddependency-demostats-for-issue-18: Dogfood ObservedDependency DemoStats for issue 18 |
| 2026-07-18 | CHG-0012-dogfood-securestate-secret-keychain-demo-key-for-issue-16: Dogfood SecureState secret Keychain demo key for issue 16 |
| 2026-07-18 | CHG-0013-dogfood-appstate-slice-via-profilename-for-issue-17: Dogfood AppState Slice via profileName for issue 17 |
| 2026-07-18 | CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15: Remove JSONCoding.decode |
| 2026-07-18 | CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15: Remove unreachable APSError.unknownKey and JSONCoding.decode for issue 15 |
| 2026-07-18 | CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38: Loud torn FileState reads + multi-writer docs |
| 2026-07-18 | CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38: Loud torn FileState reads and document multi-writer semantics for issue 38 |
| 2026-07-18 | CHG-0022-tty-aware-output-git-porcelain-rule-for-issue-33: TTY-aware output under the git porcelain rule for issue 33 |
| 2026-07-19 | CHG-0021-tty-aware-output-under-the-git-porcelain-rule-issue-33: TTY-aware output under the git porcelain rule (issue 33) |
| 2026-07-19 | CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35: Encrypted-file secret store via swift-crypto (issue 35) |
| 2026-07-19 | CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64: Dynamic schema registry and 1.0.0 prep (issues 62-64) |
| 2026-07-19 | CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64: Implement dynamic schema registry and public-ready 1.0.0 prep for issues 62-64 |
| 2026-07-22 | CHG-0041-serialize-cross-process-filestate-and-slice-profile-read-modify-write-operations: Serialize cross-process FileState and Slice profile read-modify-write operations |
| 2026-07-22 | Issue-0097-linux-safe-watch-polling: Replace RunLoop limit-date polling with cancellation-safe sleeps. |
| 2026-07-23 | CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch: Harden adversarial findings: safer reset, secret SET unlock, root state-dir, schema lock |
| 2026-07-26 | CHG-0038-harden-adversarial-findings-safer-reset-secret-set-unlock-root-state-dir-sch: Harden adversarial findings: safer reset, secret SET unlock, root state-dir, schema lock |
| 2026-07-26 | CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for: Prevent schema-controlled paths from deleting or escaping the APS state root for issue 111 |
| 2026-07-27 | CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112: Make schema.json authoritative for built-in and dynamic key names for issue 112 |
| 2026-07-27 | CHG-0049-make-reset-and-purge-transactional-and-truthfully-report-failures-for-issue-113: Make reset and purge transactional and truthfully report failures for issue 113 |
| 2026-07-27 | CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118: Harden passphrase envelopes and existing secret-key validation for issue 118 |
| 2026-07-28 | CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re: Finalize PR 128 review corrections for secure key lifecycle and CLI recipient reuse |
| 2026-07-28 | CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r: Close final PR 128 review gaps for malformed recipient modes, POSIX permission races, and pinned encrypted watch roots |
| 2026-07-28 | CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo: Enforce recursive dynamic object and Slice typing and restore schema metadata for issue 114 |
| 2026-07-28 | CHG-0056-close-final-pr-129-review-gaps-for-recursive-json-kinds-nonfinite-validation-a: Close final PR 129 review gaps for recursive JSON kinds, nonfinite validation, and corrupt StoredState reads |
| 2026-07-28 | CHG-0057-close-remaining-pr-129-validation-gaps-for-encrypted-watch-slice-shapes-bool-t: Close remaining PR 129 validation gaps for encrypted watch, Slice shapes, Bool tokens, and StoredState numeric kinds |
| 2026-07-28 | CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext: Reject oversized integral JSON without rounding and validate decrypted plaintext during encrypted disk-state preflight |
