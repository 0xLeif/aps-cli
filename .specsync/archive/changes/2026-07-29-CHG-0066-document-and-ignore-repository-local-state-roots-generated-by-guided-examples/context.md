---
change: CHG-0066-document-and-ignore-repository-local-state-roots-generated-by-guided-examples
artifact: context
---

# Context

The guided examples create repository-local APS state roots during hands-on use.
Those generated values should never appear as untracked project files or be
committed accidentally. The repository already excludes each example root; this
change records that policy independently from the already-applied documentation
change.
