# Agent memory

This example gives one agent a durable, typed checkpoint that survives terminal
and model-session restarts.

```bash
APS_HOME="$PWD/.agents/codex" ./examples/agent-memory/run.sh
APS_HOME="$PWD/.agents/codex" aps dump --json
```

The example records:

- current issue number
- branch
- workflow phase
- test status
- blocker text

Give every concurrent agent its own root:

```text
.agents/
    codex/
    cursor/
    kimi/
```

Use GitHub issues, labels, and PRs as the shared coordination authority. aps is
the agent's local memory and does not claim tickets or provide distributed
locking.
