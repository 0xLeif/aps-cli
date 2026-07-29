---
change: CHG-0065-add-runnable-agent-ci-swift-integration-and-release-pipeline-examples-with-re
artifact: context
---

# Context

aps already exposes the primitives needed by agents and automation, but the
README demonstrates commands in isolation. Users need complete examples that
show state-root isolation, persistent dynamic keys, cross-process reads,
cross-job transfer, Swift-driven integration, and release checkpoints.

The examples must remain honest about the product boundary: aps is local typed
state, not a distributed lock, secret manager, message queue, or replacement
for GitHub outputs.
