---
change: CHG-0036-archive-chg-0035-post-merge-and-exempt-specsync-lifecycle-dirs-from-sdd-coverage
artifact: context
---

# Context

Issue #74 follow-up: archiving CHG-0035 after #76 merged (the new AGENTS.md routine) surfaced a structural gap. aps-cli's sdd.json uses the repo-wide "." meaningful_paths catch-all, so archive moves (deleting .specsync/changes/CHG-x and adding .specsync/archive/changes/DATE-CHG-x) count as meaningful changed paths. With every prior change archived, no active change remains to cover them, so `specsync change check` fails on a pure archive housekeeping PR. Upstream spec-sync avoids this by never listing .specsync/ as meaningful. This change exempts the tool-managed lifecycle dirs via ignored_paths (`.specsync/changes/` and `.specsync/archive/`) so archive-only PRs pass with zero active changes, refines the AGENTS.md rule to match, and ships the already-performed CHG-0035 archive with coverage (this change covers the sdd.json policy edit, which stays protected/meaningful by design).
