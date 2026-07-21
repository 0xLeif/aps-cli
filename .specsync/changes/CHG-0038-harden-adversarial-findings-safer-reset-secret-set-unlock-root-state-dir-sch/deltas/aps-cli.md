# aps-cli harden adversarial findings

## ADDED

### REQUIREMENT REQ-aps-cli-023

`aps reset --all` SHALL restore only DemoKey seed keys. `aps reset --registered` SHALL
restore every key in the active `schema.json` registry. Passing both, or a key with
either flag, SHALL fail with a validation error.

Acceptance Criteria
- After `key add` + `set`, `reset --all` leaves the user key value unchanged.
- `reset --registered` restores that user key to its initial value.
- JSON payloads use `"reset":"all"` for `--all` and `"reset":"registered"` for `--registered`.

### REQUIREMENT REQ-aps-cli-024

`aps schema` SHALL advertise root-or-subcommand `--state-dir`, reset `--registered`, and
bump integer `schemaVersion` to 4 for this contract shape change.

Acceptance Criteria
- `aps schema` emits `"schemaVersion":4`.
- The `reset` command entry lists flags including `--registered`.

## MODIFIED

### REQUIREMENT REQ-aps-cli-011

Commands that touch FileState SHALL resolve the state directory as `--state-dir` (accepted
before the subcommand or on the subcommand), then `APS_HOME`, then `~/.aps`. A subcommand
`--state-dir` wins over a peeled root `--state-dir`.

Acceptance Criteria
- `aps --state-dir PATH get note` uses PATH.
- `aps get note --state-dir PATH` still works.
- Subcommand `--state-dir` overrides a root `--state-dir` when both are present.
- When neither is set, FileState lands under `~/.aps`.

### REQUIREMENT REQ-aps-cli-020

The `secret` key SHALL be backed by an encrypted-file secret store under the state root
(ephemeral X25519 + HKDF + ChaCha20-Poly1305 via swift-crypto), with zero interactive
prompts in key-file mode and passphrase mode via `APS_SECRET_PASSPHRASE`. When
`secret.enc` already exists, `set` SHALL unlock with the current recipient key before
rewriting; unlock failure SHALL leave the file unchanged and surface
`APSError.secretUnlockFailed`. Passphrase vs key-file mode remains stateful: a fresh or
reset store seals with whichever recipient is active on first write.

Acceptance Criteria
- `secret` round-trips set/get/reset with ciphertext at rest in `secret.enc`; the key file is mode 0600.
- Wrong passphrase on `get` fails with `secretUnlockFailed`.
- Wrong passphrase on `set` against an existing envelope fails with `secretUnlockFailed` and does not change ciphertext.
- Corrupt envelope fails with `APSError.decodingFailed`.

### REQUIREMENT REQ-aps-cli-019

`aps schema` SHALL emit one cacheable JSON document describing the CLI contract: cliVersion, integer schemaVersion (bumped when the document shape changes), state-root precedence, live registered keys, `userSchema` meta (formatVersion, keyCount, hash), commands, payload shapes, and the error table.

Acceptance Criteria
- Output is valid JSON with top-level integer `schemaVersion` equal to 4 after this change.
- Keys cover every entry in the active `schema.json`; commands cover every subcommand including `key`.
- `cliVersion` equals `aps --version`.
- `userSchema.hash` changes when the registry changes.
- Live values stay in `dump`.

### SPEC SECTION Invariants

1. The CLI entry point runs on the real main thread so AppState
   `notifyChange()` assertions hold on Linux and macOS.
2. stdout for `get` / `set` / `watch` / `reset <key>` is only the value line(s);
   stdout stays empty on error; help uses ArgumentParser defaults and domain
   errors use the Error Cases contract (human line plus optional JSON envelope).
   Piped output stays plain: no ANSI styling and compact JSON off-TTY.
3. `State` keys are process-local; a new process must not be expected to retain
   `counter` or `message`.
4. `watch` must flush each printed value immediately when stdout is not a TTY.
5. `keys` and `--help` do not mutate application state.
6. State root: subcommand `--state-dir` > root `--state-dir` > `APS_HOME` > `~/.aps`.
7. EncryptedFile SET never clobbers ciphertext without a successful unlock when a file exists.
8. `watch` termination is observable in both channels: a terminal
   `{"type":"end","reason":"count|timeout|sigint|sigterm"}` event in `--jsonl`
   mode or a stderr line in human mode, with exit codes 0 (count), 124
   (timeout), 128+signal (130 SIGINT, 143 SIGTERM). The `--jsonl` stream never
   contains non-JSON lines. An unbounded watch prints a one-time stderr hint
   suggesting `--count` / `--timeout`.
