# Agent memory

This example gives one agent a durable, typed checkpoint that survives terminal
and model-session restarts.

```bash
APS_HOME="$PWD/.agents/codex" \
CURRENT_ISSUE=142 \
WORKING_BRANCH=agent/issue-142 \
WORK_PHASE=implementing \
TESTS_PASSED=false \
BLOCKER="" \
./examples/agent-memory/run.sh

APS_HOME="$PWD/.agents/codex" ./examples/agent-memory/run.sh
```

The script emits one JSON checkpoint containing only these example keys. It
does not dump unrelated keys or secrets that may exist in the same state root.

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
