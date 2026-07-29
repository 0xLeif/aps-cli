---
change: CHG-0067-harden-guided-examples-against-secret-dumps-large-schemas-and-incompatible-key
artifact: context
---

# Context

PR #140 merged its guided workflows after all required checks passed. An
exact-head automated review completed at the merge boundary and identified
three remaining example-only hazards: the agent startup guide still dumped all
registered values, `grep -q` could short-circuit a large key inventory under
`pipefail`, and name-only reuse could accept incompatible checkpoint keys.
