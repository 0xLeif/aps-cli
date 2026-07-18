# aps v1.1: agent-ready AppState dogfood harness

## Goal

Make `aps` reliable enough for agents to inspect, mutate, and watch fixed demo AppState through stable CLI contracts.

## Why now

- v1 shipped the baseline CLI and AppState demo surface (PR #1).
- Agents need predictable JSON, state isolation, and bounded watch behavior before deeper dogfood use.
- The next milestone should harden existing scope without SyncState, plugins, daemons, or dynamic schemas.

## Success criteria

- [ ] Core README commands support machine-readable JSON output with `--json`.
- [ ] JSON output is stable, valid, documented, and covered by tests.
- [ ] State root is configurable through `APS_HOME`.
- [ ] `--state-dir` overrides `APS_HOME` for commands that touch state.
- [ ] State directory behavior is tested for default, environment, and flag-based paths.
- [ ] `watch` supports bounded execution with `--count` and `--timeout`.
- [ ] `watch` supports newline-delimited JSON output with `--jsonl`.
- [ ] Linux CI runs a smoke workflow that builds the CLI and exercises core commands.
- [ ] One deeper AppState dogfood path uses structured `FileState` (persistence, paths, Codable, watch) without dynamic schemas.
- [ ] SpecSync artifacts from v1 are archived after merge; active SpecSync content tracks v1.1 work.
- [ ] README explains JSON mode, state root configuration, watch bounds, and the FileState dogfood flow.

## Explicit out of scope

- SyncState, SecureState, and ModelState
- Plugin APIs, daemon mode, network APIs, or background services
- Dynamic schema language or user-defined state keys
- Production-grade persistence guarantees beyond the fixed demo state root
- Cross-platform CI beyond the Linux smoke workflow

## Workstreams

### A. CLI contracts and state root

1. Add `--json` for core commands used in README examples
2. Define stable JSON shapes and error output
3. Add `APS_HOME` and `--state-dir`
4. Test default, env, and flag-based state roots

### B. Watch hardening and FileState dogfood

1. Add `watch --count` and `--timeout`
2. Add `watch --jsonl`
3. Add structured `FileState` dogfood key/model
4. Test watch bounds and JSONL event shape

### C. CI, SpecSync, and docs

1. Add Linux CI smoke workflow
2. Archive merged v1 SpecSync change (this PR starts that)
3. Keep active SpecSync focused on v1.1 delivery
4. Update README agent-usage examples

## Definition of done

All success criteria checked; tests and Linux CI smoke pass on main; README examples work from a clean checkout; JSON/JSONL documented; v1 SpecSync archived; no out-of-scope systems introduced.
