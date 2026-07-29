# Using aps in projects, agents, and CI

aps is a typed local state layer. It is most useful when several commands or
processes need to share discoverable state without introducing a service or
database.

## Choose aps when

- state must survive a new shell, process, or agent session
- humans and automation need the same inspectable values
- a schema and stable JSON output are valuable
- another process should observe changes with `aps watch`
- a CI job needs more structure than a few environment variables

Use an environment variable or `GITHUB_OUTPUT` for a small, one-way value. Use a
database, queue, or coordination service for networked state or competing
writers.

## Agent memory

Give each agent a dedicated root:

```bash
export APS_HOME="$PWD/.agents/codex"
aps schema --json
aps dump --json
```

At the start of a session, the agent rediscovers the live schema and values. At
each meaningful checkpoint, it updates its issue, branch, phase, tests, and
blocker. See the runnable [agent-memory example](../examples/agent-memory/).

Use separate roots for Codex, Cursor, Kimi, and other concurrent agents. GitHub
labels and pull requests remain the shared ticket authority.

## GitHub Actions

Steps in one job share `APS_HOME`. Jobs use isolated machines, so transfer the
state root with `actions/upload-artifact` and `actions/download-artifact` when a
later job needs it. The complete [GitHub Actions example](../examples/github-actions/)
installs the portable Linux release and demonstrates both jobs.

Prefer native job outputs when only a scalar result crosses the boundary.
Artifacts are appropriate when the schema and several state files form one
reviewable snapshot.

## Swift integration tests

A Swift test harness can invoke aps to seed or inspect AppState-backed state
without adding a UI control surface. This is useful for feature flags, fixture
profiles, migration tests, and post-run inspection.

The [Swift harness example](../examples/swift-harness/) compiles a small
Foundation program, writes a structured profile, and reads it back through a
fresh aps process.

## Release pipelines

Release automation can expose its current candidate and phase:

```bash
aps set releasePhase verifying
aps set releaseTestsPassed true
aps set riskVerdict proceed
```

This makes a local release script observable to agents and terminal dashboards.
It does not replace signed Attest provenance, the immutable tag, or CI evidence.
See the [release-pipeline example](../examples/release-pipeline/).

## Repository layout

Commit a project schema only when every contributor should share the same key
contract. Ignore runtime values while allowing the schema:

```gitignore
.aps/*
!.aps/schema.json
```

For agent-local roots, normally ignore the complete `.agents/` directory.

## Safety boundaries

- Use one writer per key unless its adapter documents stronger behavior.
- Give concurrent agents separate roots or keys.
- `State` values are process-local; use FileState for cross-process examples.
- aps has no network synchronization or distributed locks.
- GitHub Actions jobs require artifact transfer for shared roots.
- Key-file encrypted state does not protect against compromise of the complete
  state root.
- Never publish an encrypted envelope together with its private key.
- Use GitHub Secrets or a dedicated secret manager for CI credentials.

## Start from an example

The [`examples/` index](../examples/) provides copyable workflows for agent
memory, GitHub Actions, a Swift harness, and release automation.
