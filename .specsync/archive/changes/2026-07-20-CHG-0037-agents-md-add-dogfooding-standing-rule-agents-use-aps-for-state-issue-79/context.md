---
change: CHG-0037-agents-md-add-dogfooding-standing-rule-agents-use-aps-for-state-issue-79
artifact: context
---

# Context

Issue #79 (owner direction 2026-07-20): agents on this repo should dogfood aps as their state tool, not just test it. The fledge plugin is live-linked from this clone (`fledge aps`, v1.0.0) and the tap install works, so the standing rules should direct agents to persist working/session state in the default state root (`~/.aps`) with their own keys via `aps key add` + `set`/`get`, keeping the demo keys for tests and smoke. Kimi has already started: `agentStatus` key recorded in the default root.
