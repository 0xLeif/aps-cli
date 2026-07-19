# RFC: Dynamic schema (user-defined keys)

Issue: [#39](https://github.com/0xLeif/aps-cli/issues/39)  
Status: **Accepted design** (documentation only; no runtime implementation in this change)  
Authors: agent:cursor (2026-07-19)  
Depends on: error contract ([#31](https://github.com/0xLeif/aps-cli/issues/31)), `aps schema` ([#32](https://github.com/0xLeif/aps-cli/issues/32))  
Milestone: v1.0.0

## Verdict

**Go** for 1.0, behind a phased implementation plan.

`aps` stays a small CLI, but the fixed `DemoKey` enum stops being the long-term product boundary. The state root gains a versioned `schema.json` that lists keys; the built-in demo keys ship as the default contents of that file. Agents keep discovering the live key set through `aps schema` / `aps keys`, which become projections of `schema.json` plus the static command/error contract.

## Problem

Today every key is a compile-time `DemoKey` case. That was correct for the 0.x dogfood harness. It blocks the 1.0 headline: a general-purpose state CLI where humans and agents declare their own keys without shipping a new `aps` binary.

Constraints already locked by the rest of the 0.x train:

- Machine contract is stable: JSON payloads, exit codes, error envelopes ([#31](https://github.com/0xLeif/aps-cli/issues/31)).
- `aps schema` is the cacheable contract endpoint ([#32](https://github.com/0xLeif/aps-cli/issues/32)).
- State root resolution is `--state-dir` > `APS_HOME` > `~/.aps`.
- Secrets use an encrypted file under the state root ([#35](https://github.com/0xLeif/aps-cli/issues/35)), not Keychain.

## Locked decisions (design interview, 2026-07-18)

1. **Source of truth:** `<state-root>/schema.json` (diffable, committable, fits SpecSync culture).
2. **Sugar UX:** `aps key add` / `aps key remove` (and likely `aps key list`) edit that file; they do not invent a second registry.
3. **Default namespace:** the current demo keys ship as the initial `schema.json` contents (not a separate parallel system).

## Goals

- Agents can add a key, set/get/watch/reset it, and rediscover it via `aps schema` / `aps keys` without a rebuild.
- Schema files are reviewable in git and portable across machines that share a state root (or copy `schema.json` + data files).
- SpecSync continues to contract the *CLI core* (commands, payloads, error table, schema file format). Runtime key inventories are not frozen into `*.spec.md` as an enum of names.
- Existing demo-key behavior remains the default for empty or freshly initialized state roots.

## Non-goals (1.0)

- Arbitrary expression languages, computed fields, or workflows.
- Cross-root schema sync / iCloud (SyncState remains no-go; see `docs/spikes/`).
- Full JSON Schema validation engine in-process (emit shapes; do not become a general validator).
- Hot-reloading AppState property wrappers generated at runtime from Swift macros (too heavy for a CLI).
- Removing the demo keys from the default schema.

## Design

### 1. `schema.json` layout

Path: `<state-root>/schema.json`  
Encoding: UTF-8 JSON, pretty-printed on write (same style as CLI `--json` pretty output).

Proposed shape (illustrative; freeze in implementation SpecSync deltas):

```json
{
  "formatVersion": 1,
  "namespace": "default",
  "keys": [
    {
      "name": "counter",
      "type": "Int",
      "storage": "State",
      "initial": "0",
      "doc": "in-memory Int counter (process lifetime)"
    },
    {
      "name": "note",
      "type": "String",
      "storage": "FileState",
      "path": "note.json",
      "initial": "",
      "doc": "String via FileState"
    },
    {
      "name": "profile",
      "type": "object",
      "storage": "FileState",
      "path": "profile.json",
      "objectShape": {
        "name": "String",
        "version": "Int"
      },
      "initial": {"name": "", "version": 0},
      "doc": "structured profile document"
    },
    {
      "name": "secret",
      "type": "String",
      "storage": "EncryptedFile",
      "path": "secret.enc",
      "initial": "",
      "doc": "encrypted string under the state root"
    },
    {
      "name": "profileName",
      "type": "String",
      "storage": "Slice",
      "sliceOf": "profile",
      "sliceField": "name",
      "doc": "projection of profile.name"
    }
  ]
}
```

Rules:

| Rule | Detail |
|------|--------|
| `formatVersion` | Integer; bump only on breaking schema-file shape changes |
| `name` | `[A-Za-z][A-Za-z0-9_]*`, unique within the file |
| Reserved names | None beyond uniqueness; demo names are ordinary entries |
| `storage` | Closed enum for 1.0: `State`, `StoredState`, `FileState`, `EncryptedFile`, `Slice` |
| `type` | Closed enum for 1.0: `Int`, `String`, `Bool`, `object` |
| `object` | Requires `objectShape` (flat string->primitive map for 1.0; nested objects deferred) |
| `Slice` | Requires `sliceOf` + `sliceField` pointing at an `object` key |
| `path` | Required for `FileState` / `EncryptedFile`; relative to state root; no `..` segments |
| `initial` | Required; used by `reset` and first read |

Missing `schema.json` on an existing state root: **materialize the built-in default** (demo keys) on first mutating command or on `aps key` / `aps schema` that needs it, then continue. Never invent empty schemas for legacy roots that already have `note.json` / `profile.json` without a file.

### 2. Declaration UX

| Surface | Role |
|---------|------|
| `<state-root>/schema.json` | Canonical registry |
| `aps key add <name> --type … --storage …` | Creates/updates an entry, writes the file, exits non-zero on conflict/invalid |
| `aps key remove <name>` | Removes entry; does **not** delete data files by default (`--purge` opt-in) |
| `aps key list [--json]` | Human/agent listing (subset of `aps keys`) |
| Hand-editing `schema.json` | Supported; next `aps` command validates and fails with `invalid_value` / dedicated `schema_invalid` if needed |

`aps keys` remains the agent-facing inventory (name/type/storage/detail). After dynamic schema lands, it reads the registry rather than `DemoKey.allCases`.

### 3. Runtime model (implementation sketch)

Replace compile-time-only dispatch with a loaded registry:

1. Resolve state root.
2. Load or materialize `schema.json`.
3. Validate format + references (slice targets, paths).
4. Bind each entry to a storage adapter:

| Storage | Adapter idea |
|---------|----------------|
| `State` | Process-local map in `Application` / in-memory box keyed by name |
| `StoredState` | UserDefaults key under a stable prefix `aps.user.<name>` |
| `FileState` | JSON file at `path` (string or object document) |
| `EncryptedFile` | Reuse #35 envelope helpers with configurable filename |
| `Slice` | Read/write parent object field |

`get` / `set` / `watch` / `reset` / `dump` take **string key names** resolved through the registry. ArgumentParser's current `DemoKey` enum becomes a compatibility layer during migration (accept known demo names) and is removed from the public CLI surface once string keys land.

Unknown key: exit **64** (`invalid_value` or a dedicated `unknown_key` code added in the same implementation change; prefer extending the #31 table once rather than inventing ad hoc messages).

### 4. Relationship to `aps schema` (#32)

Today `aps schema` emits a **static** contract (`Schema.schemaVersion`, fixed key list, commands, payloads, errors).

After this RFC:

| Field | Source |
|-------|--------|
| `cliVersion`, commands, payloads, errors, stateRoot precedence | Still static (compiled contract) |
| `keys` | **Dynamic:** projection of `schema.json` |
| `schemaVersion` | Static integer for the *contract document shape* (commands/payloads/errors). Bump when the CLI contract changes, not when a user adds a key |
| New: `userSchema.formatVersion` | Echo of `schema.json`'s `formatVersion` |
| New: `userSchema.hash` (optional) | Stable hash of canonicalized `schema.json` so agents detect key-set drift without diffing the whole keys array |

Agents that cached `aps schema` must treat `keys` as mutable. Equality checks on `schemaVersion` alone are no longer enough to assume the key list is unchanged; they should compare `userSchema.hash` or re-fetch `keys`.

### 5. SpecSync / specs strategy

| Layer | Contract home |
|-------|----------------|
| CLI commands, flags, payloads, error codes, `schema.json` format | `specs/aps-cli` (+ `state-store` for persistence adapters) |
| Concrete demo key names in default schema | Documented as **default seed data**, not as an open-ended requirement that forbids other keys |
| User-added keys at runtime | **Out of SpecSync enum scope**; verified by tests that add a temporary key under a temp state root |

Implementation SpecSync change (future, not this RFC) should:

- MODIFY purpose text: fixed demo schema -> registry-backed schema with demo defaults.
- ADD requirements for `schema.json` validation, `aps key add/remove`, and migration/materialization.
- Keep export tables for core types (`APSError`, payload structs); stop requiring every key name as a Swift enum case forever.

### 6. Type system (1.0)

Reuse the current value surface:

| Type | Wire form (set/get string CLI) | Notes |
|------|-------------------------------|-------|
| `Int` | decimal string | Same as `counter` |
| `String` | raw string | |
| `Bool` | `true`/`false`/`1`/`0` (existing `parseBool`) | |
| `object` | JSON object string | Flat fields only in 1.0 |

Deferred: arrays, nested objects, enums, decimals, timestamps as first-class types.

### 7. Migration path for demo keys

| Phase | Behavior |
|-------|----------|
| A. Ship RFC (this change) | Docs only |
| B. Dual-read | Code still has `DemoKey`, but also reads `schema.json` when present |
| C. Materialize | On boot of a state root without `schema.json`, write the default demo schema |
| D. String keys | CLI accepts any registered name; `DemoKey` becomes internal seed only |
| E. Cleanup | Remove `ExpressibleByArgument` enum from public CLI; keep seed builder for defaults |

Data files (`note.json`, `profile.json`, `secret.enc`, UserDefaults `flag`) keep their current paths so existing roots do not break when `schema.json` appears.

### 8. Errors and exits

Reuse #31 taxonomy. Likely additions at implementation time (not in this RFC's code):

| Code | Exit | When |
|------|------|------|
| `schema_invalid` | 65 | `schema.json` present but undecodable / fails validation |
| `unknown_key` | 64 | name not in registry |
| `schema_conflict` | 64 | `key add` overwrites without `--force` |

Torn FileState files remain `corrupt_state` / 65.

### 9. Security notes

- `EncryptedFile` keys each get their own `path` (default `secret.enc` for the demo entry). Do not share one envelope across unrelated secrets without an explicit design follow-up.
- `aps key remove --purge` is the only path that deletes ciphertext/key material; document it loudly.
- Schema edits are not authenticated; anyone who can write the state root can change types. Same trust model as today's FileState files.

## Alternatives considered

| Option | Why rejected for 1.0 |
|--------|----------------------|
| Schema only via CLI, no file | Not diffable/committable; fights SpecSync culture |
| Schema only via file, no `key add` | Hostile to agents; file edit is error-prone |
| Keep `DemoKey` forever + parallel user map | Two sources of truth; `aps schema` becomes confusing |
| Full JSON Schema + codegen | Overkill; slows the CLI; duplicates #32's minimal shapes |
| Per-key Swift plugins | Violates "no plugin API inside aps" 0.x non-goal spirit for 1.0 core |

## Implementation plan (go)

Ordered work once this RFC merges:

1. **Schema file IO + validation** (load/materialize/write, path safety, slice refs).
2. **Registry resolve** for get/set/reset/dump/keys against string names (demo seed parity tests).
3. **`aps key add|remove|list`** sugar with JSON errors.
4. **Dynamic `aps schema` keys projection** + `userSchema.hash`; bump static `schemaVersion` when the contract document gains fields.
5. **Watch** against registry keys (poll path first; Match current signal/TTY behavior).
6. **Docs + smoke**: seed schema in smoke state roots; add/remove round-trip in `Scripts/smoke.sh` / `smoke.ps1`.
7. **Remove CLI `DemoKey` argument type** after parity.

Suggested tracking: open implementation issues from this list when starting 1.0 coding (do not block on #40's public flip for the first phases; dynamic schema can land in a 1.0.0-rc while the repo is still private).

## Test plan (for the future implementation change)

- Temp state root: materialize default schema equals demo inventory.
- `key add` then `set`/`get`/`reset` for `Int`/`String`/`Bool`/`FileState`/`EncryptedFile`.
- `object` + `Slice` round-trip (`profile` / `profileName` seed remains green).
- Invalid schema file -> exit 65 / `schema_invalid`.
- Unknown key -> exit 64.
- `aps schema` keys reflect add/remove; `schemaVersion` unchanged on key add; `userSchema.hash` changes.
- Windows + Linux smoke still pass.

## Open questions (non-blocking)

1. Should `StoredState` user keys share one UserDefaults suite / prefix forever? (Recommend yes: `aps.user.<name>`.)
2. Exact name for the unknown-key error code (`unknown_key` vs reuse `invalid_value`). Prefer `unknown_key` for agent clarity.
3. Whether `aps schema --static` should exist for CI contract snapshots without reading the state root. Nice-to-have; default remains "project keys from active root."

## Go / no-go

| Question | Answer |
|----------|--------|
| Ship the RFC now? | **Go** |
| Start implementation immediately after merge? | **Go**, as a separate SpecSync change series under milestone v1.0.0 |
| Block on #40 public flip? | **No** |
| Block on expanding types beyond Int/String/Bool/object? | **No** (defer) |

## Related

- [`aps schema` contract](../../Sources/aps/Schema.swift) (issue #32)
- [Windows readiness](../windows-readiness.md) (tri-OS CI for 1.0)
- [Go-public checklist](https://github.com/0xLeif/aps-cli/issues/40)
- Error contract (#31), encrypted secret store (#35)
