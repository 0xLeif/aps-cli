---
change: CHG-0035-archive-accepted-specsync-backlog-31-changes-bump-specsync-pin-to-5-2-0-add
artifact: testing
---

# Testing

- Root causes reproduced and diagnosed against the spec-sync source: coverage preflight (needs empty delivery diff vs origin/main) and historical-integrity preflight (5.1.1 cannot authenticate squash-merged evidence refreshes; fixed in 5.2.0 per upstream tests `accepted_evidence_survives_integrated_squash_merge_and_archives` and `refreshed_accepted_evidence_squash_merged_while_accepted_archives`).
- Sweep executed with the 5.2.0 binary: 33 of 33 archive operations succeeded (31 backlog + CHG-0003/0004 from the diagnostic phase).
- `specsync change check --strict` must pass with zero active changes left and this change accepted.
- `fledge lanes run verify` must pass (build + test + smoke + plugin-validate).
- Trust CI on the PR validates the 5.2.0 mirror pin end to end.
