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

## Dogfooding aps

Use the tool itself for agent state on this project: `fledge aps` (live-linked
plugin) or `aps` from the tap. Persist working/session state in the default
state root (`~/.aps`) with `aps key add` + `set`/`get` instead of scratch
files. Leave the demo keys for tests and smoke; add your own keys for real
state (see `docs/design/dynamic-schema.md`).

## Multi-agent ticket claiming

Multiple agents (Kimi, Cursor, others) work GitHub issues autonomously in
this repo. Coordinate through labels, not assignees:

| Label | Agent |
|-------|--------|
| `agent:cursor` | Cursor cloud / coding agents |
| `agent:kimi` | Kimi Code agent |

Rules:

1. Before picking up an issue, read its labels and linked PRs. Skip if an
   `agent:*` label or a linked open PR is present (unless the label is yours).
2. Claim by adding your `agent:<name>` label only, and comment with your
   agent name and working branch.
3. One agent label per ticket, one ticket per branch/PR.
4. Fan out subagents only on tickets you have claimed. Pass the issue number
   and claim label into each subagent prompt.
5. Remove your label when the implementing PR is open or when you stop work,
   and link the outcome so another agent can take it.
6. After the implementing PR merges, archive its SpecSync change:
   `specsync change archive <id>` from a clean main-based checkout, pushed
   as a small housekeeping PR. Archive moves are exempt from SDD coverage
   (`.specsync/changes/` and `.specsync/archive/` sit in `ignored_paths`),
   so the housekeeping PR needs no covering change. The archive preflight
   needs an empty delivery diff vs `origin/main` and the pinned specsync
   release (`.specsync/version`; 5.2.0+ understands squash-merged
   evidence). `accepted` is not the terminal state; do not let accepted
   changes pile up in `.specsync/changes/`.
7. Prefer unclaimed open issues. Do not strip another agent's claim label.
8. If your `agent:<name>` label does not exist, create it with a description
   of the form "Ticket claimed by <name>".

### Worktrees for parallel agents

Local agents share this checkout, so parallel work needs isolation: one git
worktree per claimed ticket, kept out of the main checkout.

```sh
git worktree add ../aps-cli-wt/issue-N -b <agent>/issue-N-<slug> origin/main
```

- Work only inside your worktree; leave the main checkout on `main`.
- Each worktree carries its own `.build/`; that is the cost of isolation.
- SpecSync SDD workspaces (`.specsync/changes/`) are per-worktree, so
  in-flight tickets merge in order like any other change.
- Remove the worktree and branch once the PR is up.
- Cloud agents (Cursor background, Codex) already run isolated VMs; this
  rule is for agents on a shared machine.

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
