---
change: CHG-0036-archive-chg-0035-post-merge-and-exempt-specsync-lifecycle-dirs-from-sdd-coverage
artifact: plan
---

# Plan

1. sdd.json: `ignored_paths` gains `.specsync/changes/` and `.specsync/archive/` (protected files like sdd.json and change-sequence.json stay meaningful via `is_protected_sdd_path`).
2. AGENTS.md rule 6: note that archive moves are exempt from SDD coverage, so the housekeeping PR needs no covering change.
3. CHG-0035's archive (already performed on this branch) rides along, covered by this change.
4. Verify + `specsync change check --strict`; after merge, archive CHG-0036 itself as the final step, leaving zero accepted changes.
