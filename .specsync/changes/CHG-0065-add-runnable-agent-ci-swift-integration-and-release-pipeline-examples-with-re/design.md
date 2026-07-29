---
change: CHG-0065-add-runnable-agent-ci-swift-integration-and-release-pipeline-examples-with-re
artifact: design
---

# Design

Add an `examples/` index with four focused examples:

1. Agent memory uses a dedicated `APS_HOME` and persistent FileState keys.
2. GitHub Actions transfers a state root between jobs as an artifact.
3. A Swift harness drives the AppState-backed CLI as an integration boundary.
4. A release pipeline records version, commit, phase, tests, and risk.

Shell examples accept `APS_BIN` and `APS_HOME` so automated tests can run them
against an isolated build. The Swift example compiles into a temporary
directory. Documentation links to the examples from both navigation entry
points and explains when simpler native primitives remain preferable.
