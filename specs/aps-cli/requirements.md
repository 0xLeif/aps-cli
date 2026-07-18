---
spec: aps-cli.spec.md
---

# Requirements -  APS CLI

## Functional

### REQ-aps-cli-001

The fixed demo schema SHALL include `profile` alongside `counter`, `message`, `flag`, and `note`.

Acceptance Criteria
- `aps keys` lists `profile`.
- `aps set profile '{"name":"a","version":1}'` round-trips through get/dump/reset.

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

`APSError` SHALL cover `unknownKey`, `invalidValue`, `encodingFailed`, `decodingFailed`, and `persistenceFailed`.

Acceptance Criteria
- Each case has an actionable `description`.
- `set note` surfaces `persistenceFailed` when the on-disk value does not match after write.

### REQ-aps-cli-010

`get`, `set`, `dump`, `keys`, and `reset` SHALL support `--json` machine-readable output.

Acceptance Criteria
- JSON payloads are valid UTF-8 JSON objects.
- Typed values preserve Int/Bool where applicable instead of always stringifying.

### REQ-aps-cli-011

Commands that touch FileState SHALL resolve the state directory as `--state-dir`, then `APS_HOME`, then `~/.aps`.

Acceptance Criteria
- `--state-dir` wins over `APS_HOME`.
- When neither is set, FileState lands under `~/.aps`.

### REQ-aps-cli-012

`watch` SHALL support `--count`, `--timeout`, and `--jsonl`.

Acceptance Criteria
- `--count` stops after that many printed values including the initial value.
- `--timeout` stops after the given seconds.
- `--jsonl` emits one JSON object per line.

### REQ-aps-cli-013

The CLI `--version` string SHALL be `0.2.0` while the project is pre-public 0.x.

Acceptance Criteria
- `aps --version` prints `0.2.0`.

