# state-store registered encrypted watch root pinning

## ADDED

### REQUIREMENT REQ-state-store-025

Registered encrypted watch SHALL pin the canonical state-root target selected
by its initial encrypted store for the watch lifetime. Each poll SHALL continue
to reconstruct and validate the encrypted store beneath that pinned root so a
configured root-symlink retarget cannot redirect the watch and descendant
replacement remains detectable.

Acceptance Criteria
- A watch started through a root symlink emits only the initial target after
  that symlink is retargeted.
- Existing descendant-symlink replacement rejection remains covered.
