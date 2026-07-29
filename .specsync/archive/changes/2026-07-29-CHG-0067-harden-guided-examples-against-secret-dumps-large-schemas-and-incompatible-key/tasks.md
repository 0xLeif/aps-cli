---
change: CHG-0067-harden-guided-examples-against-secret-dumps-large-schemas-and-incompatible-key
artifact: tasks
---

# Tasks

- [x] Replace the unfiltered agent startup dump with checkpoint-only inspection.
- [x] Make key inventory membership consume the complete producer output.
- [x] Validate type, storage, documentation, and backing path before reusing keys.
- [x] Add regressions for secrets, large inventories, and incompatible collisions.
- [x] Run and record full verification.
