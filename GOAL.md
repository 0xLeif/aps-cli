# aps 0.2.0: agent-ready AppState dogfood harness

## Goal

Make `aps` reliable enough for agents to inspect, mutate, and watch fixed demo AppState through stable CLI contracts while the project remains pre-public 0.x.

## Why now

- 0.1.0 shipped the baseline CLI and AppState demo surface (PR #1).
- Agents need predictable JSON, state isolation, and bounded watch behavior.
- Stay on 0.x until the repo is public; do not imply a 1.0 release.

## Success criteria

- [x] `get`, `set`, `dump`, `keys`, and `reset` support `--json`.
- [x] State root is configurable through `APS_HOME`.
- [x] `--state-dir` overrides `APS_HOME` for commands that touch state.
- [x] State directory behavior is tested for default, environment, and flag-based paths.
- [x] `watch` supports bounded execution with `--count` and `--timeout`.
- [x] `watch` supports newline-delimited JSON output with `--jsonl`.
- [x] Linux CI runs a smoke workflow that builds the CLI and exercises core commands.
- [x] Demo key `profile` uses structured `FileState` with Codable `{name, version}`.
- [x] SpecSync artifacts from 0.1.x are archived; active SpecSync tracks 0.2.0 work.
- [x] README documents JSON mode, state root, watch bounds, and `profile`.
- [x] CLI `--version` reports `0.2.0`.
- [x] Demo key `secret` uses AppState `SecureState` (Keychain) with round-trip tests and documented CI behavior.
- [x] Demo key `profileName` dogfoods AppState `Slice` over `profile.name`.
- [x] `aps stats` dogfoods `@ObservedDependency` (`DemoStats`).
- [x] SyncState and ModelState feasibility spikes document no-go for 0.x (`docs/spikes/`).

## Explicit out of scope for 0.x

- SyncState and ModelState
- Plugin APIs, daemon mode, network APIs, or background services
- Dynamic schema language or user-defined state keys

## In scope (added)

- SecureState dogfood via the fixed `secret` demo key (Keychain-backed String). Available where Apple's Security framework exists (macOS). Keychain round-trip tests and smoke are opt-in (`APS_SMOKE_SECURESTATE=1`); default CI skips them to avoid Keychain prompts. Linux documents keychain-unavailable behavior.

## Tickets

| ID | Item |
|----|------|
| APS-01 | `--json` on core commands |
| APS-02 | Stable JSON shapes + tests |
| APS-03 | `APS_HOME` state root |
| APS-04 | `--state-dir` override |
| APS-05 | State-dir path tests |
| APS-06 | `watch --count` / `--timeout` |
| APS-07 | `watch --jsonl` |
| APS-08 | Linux CI smoke |
| APS-09 | Structured `profile` FileState |
| APS-10 | SpecSync archive hygiene |
| APS-11 | README agent usage |
| APS-12 | SecureState `secret` Keychain dogfood |
| APS-13 | ObservedDependency `stats` / `DemoStats` |
| APS-14 | Slice `profileName` over `profile.name` |
| APS-15 | SyncState / ModelState feasibility spikes (no-go) |

## Definition of done

All success criteria checked; tests and Linux CI smoke pass; README examples work from a clean checkout; no out-of-scope 0.x systems introduced.
