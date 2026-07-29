# aps examples

These examples turn aps commands into complete workflows. Every local example
accepts `APS_BIN` and `APS_HOME`, so it can use either an installed release or
an isolated development build.

| Example | Demonstrates | Run |
| --- | --- | --- |
| [Agent memory](agent-memory/) | Resumable state for Codex, Kimi, Cursor, or another agent | `./examples/agent-memory/run.sh` |
| [GitHub Actions](github-actions/) | Typed state across steps and jobs | Copy `workflow.yml` into a project |
| [Swift harness](swift-harness/) | A Swift integration test driving the AppState-backed CLI | `./examples/swift-harness/run.sh` |
| [Release pipeline](release-pipeline/) | Observable build, test, risk, and publication checkpoints | `./examples/release-pipeline/run.sh` |

Build aps before running examples from a source checkout:

```bash
fledge run build
export APS_BIN="$PWD/.build/debug/aps"
```

Each example uses persistent FileState keys when values must survive a new aps
process. Process-local `State` keys are intentionally avoided.

Read the [use-case guide](../docs/use-cases.md) before adapting an example for
multiple writers, cross-job artifacts, or secrets.
