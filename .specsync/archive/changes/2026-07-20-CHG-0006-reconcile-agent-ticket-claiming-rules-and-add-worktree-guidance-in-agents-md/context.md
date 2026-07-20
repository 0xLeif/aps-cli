---
change: CHG-0006-reconcile-agent-ticket-claiming-rules-and-add-worktree-guidance-in-agents-md
artifact: context
---

# Context

PR #2 shipped an "Agent ticket claims" section in AGENTS.md while PR #21
carried a parallel "Multi-agent ticket claiming" section. The rebase
reconciles both into one section and adds worktree guidance for parallel
local agents sharing one machine.

## Decisions

- Keep the label table (`agent:cursor`, `agent:kimi`) and merge both rule
  sets: label/PR check before claiming, branch comment on claim, one ticket
  per branch/PR, label creation when missing.
- Parallel local agents use per-ticket git worktrees outside the main
  checkout; cloud agents are already isolated.
