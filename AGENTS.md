# aps

A Swift CLI that dogfoods [AppState](https://github.com/0xLeif/AppState) outside SwiftUI.

## Layout

| Path | Role |
|------|------|
| `Sources/aps/` | Executable: CLI, demo Application state, StateStore |
| `Tests/apsTests/` | Round-trip, watch, reset, and dependency tests |
| `specs/` | SpecSync contracts for the CLI and state surface |
| `Scripts/smoke.sh` | End-to-end CLI smoke checks |

## Workflow

```sh
fledge lanes run verify   # build + test + smoke
fledge trust verify       # full trust gate when tools are installed
./Scripts/smoke.sh
```

<!-- CorvidLabs trust toolchain: BEGIN (managed, do not edit inside) -->
## CorvidLabs trust toolchain (standing rules)

This repo is gated by four tools, run by `.github/workflows/trust.yml`:

1. **fledge**: the quality gate. `fledge lanes run verify` runs
   build + test + smoke. Prefer fledge wrappers over raw tools.
2. **spec-sync**: specs are contracts. Each module API has a `*.spec.md`, and
   `specsync check` must pass. Skipping spec-sync for a repo needs an explicit
   one-line reason.
3. **augur**: deterministic diff-risk scoring. A `block` verdict halts the
   merge. `augur.json` is a per-run artifact and is gitignored; never commit it.
4. **attest**: signed provenance. CI records an attestation and verifies the
   range against `.attest.json`. Provenance lives in `refs/notes/attest`.

Standing rules for anyone (human or agent) changing this repo:

- Run `fledge lanes run verify` before pushing; do not bypass the gate.
- Keep specs in lockstep with code: update the `*.spec.md` in the same change.
- A `block` verdict from augur means stop and escalate, not merge.
- Do not commit `augur.json`.
- Do not use em-dash characters in authored content; use hyphens or colons.
- Runner-specific rule files (`CLAUDE.md`, `.cursor/rules/*.mdc`,
  `.github/copilot-instructions.md`) are one-line pointers to this file; do not
  duplicate these rules into them.
<!-- CorvidLabs trust toolchain: END -->
