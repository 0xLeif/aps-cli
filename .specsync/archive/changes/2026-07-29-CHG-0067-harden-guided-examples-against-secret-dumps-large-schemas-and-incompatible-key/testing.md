---
change: CHG-0067-harden-guided-examples-against-secret-dumps-large-schemas-and-incompatible-key
artifact: testing
---

# Testing

- Run the example contract against fresh and resumed roots.
- Seed incompatible keys and require both scripts to fail before mutation.
- Seed enough keys to exceed a pipe buffer and verify compatible example keys
  are still detected without a duplicate-add attempt.
- Assert documentation contains no unfiltered agent startup dump.
- Run the complete Fledge verification lane.
