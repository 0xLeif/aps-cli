---
change: CHG-0036-archive-chg-0035-post-merge-and-exempt-specsync-lifecycle-dirs-from-sdd-coverage
artifact: testing
---

# Testing

- Failure reproduced on the archive-only branch: `specsync change check` reported the CHG-0035 archive moves as meaningful changed paths with no active change to cover them.
- Root cause verified in the spec-sync source: `path_is_meaningful_with_specs` consults `ignored_paths`, `is_protected_sdd_path` keeps tool config files meaningful, and upstream spec-sync's own sdd.json never lists .specsync/ as meaningful.
- `specsync change check --strict` must pass on this branch (the exemption plus this change's coverage of sdd.json and AGENTS.md).
- `fledge lanes run verify` must pass.
