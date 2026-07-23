# aps

A Swift CLI that dogfoods [AppState](https://github.com/0xLeif/AppState) outside SwiftUI.

## Layout

| Path | Role |
|------|------|
| `Sources/aps/` | Executable: CLI, demo Application state, StateStore |
| `Tests/apsTests/` | Round-trip, watch, reset, and dependency tests |
| `specs/` | SpecSync contracts for the CLI and state surface |
| `Scripts/smoke.sh` | End-to-end CLI smoke checks |
| `Scripts/ci-dogfood.sh` | Job-scoped APS_HOME proof that CI *uses* aps |

## Workflow

```sh
fledge lanes run verify   # build + test + smoke + ci-dogfood
fledge trust verify       # full trust gate when tools are installed
./Scripts/smoke.sh
./Scripts/ci-dogfood.sh
```

## Dogfooding aps

Use the tool itself for agent and CI state on this project: `fledge aps`
(live-linked plugin) or `aps` from a local build / the tap. Prefer aps keys
over scratch files.

### Bootstrap (Linux cloud / this repo)

```sh
./Scripts/build.sh -c release    # portable; raw swift build can fail on Linux 6.0.x
export PATH="$PWD/.build/release:$PATH"
# Optional isolation from a polluted home root:
# export APS_HOME=/tmp/aps-agent-$USER
```

### Session keys (FileState only)

Leave demo seed keys (`counter`, `message`, `flag`, `note`, `profile`, `secret`,
`profileName`) for tests and `Scripts/smoke.sh`. Add your own keys:

```sh
aps key add agentStatus --type String --storage FileState --path agent-status.json --initial ''
aps key add agentIssue  --type Int    --storage FileState --path agent-issue.json  --initial 0
aps key add agentBranch --type String --storage FileState --path agent-branch.json --initial ''
aps set agentStatus exploring
aps set agentIssue 82
aps set agentBranch "$(git branch --show-current)"
aps get agentStatus --json
aps dump --json
```

Rules:

- Prefer **FileState** for anything that must survive process boundaries.
- Avoid **StoredState** for agent keys until #82 (user StoredState is not
  scoped by `--state-dir` / `APS_HOME`).
- Avoid `aps reset --all` on a dogfood root that holds agent keys (it resets
  every registered key).
- In CI, always set a job-scoped `APS_HOME` or `--state-dir` (see
  `Scripts/ci-dogfood.sh`).

See `docs/design/dynamic-schema.md` for the registry model.

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
