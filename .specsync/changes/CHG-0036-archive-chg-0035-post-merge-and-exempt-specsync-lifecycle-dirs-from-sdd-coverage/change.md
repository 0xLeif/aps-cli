---
id: CHG-0036-archive-chg-0035-post-merge-and-exempt-specsync-lifecycle-dirs-from-sdd-coverage
state: accepted
type: operations
base_commit: 1fa48c0b4a90f8918b9e911d2d7fcea008225301
---

# Archive CHG-0035 post-merge and exempt SpecSync lifecycle dirs from SDD coverage (issue 74 follow-up)

## Intent

Archive CHG-0035 post-merge and exempt SpecSync lifecycle dirs from SDD coverage (issue 74 follow-up)

## Affected Canonical Specs

- None

## Acceptance Criteria

- CHG-0035 is archived under .specsync/archive/changes/; sdd.json ignored_paths exempts .specsync/changes/ and .specsync/archive/ so archive-only housekeeping PRs pass check with zero active changes; AGENTS.md rule 6 reflects the exemption; specsync change check --strict passes

## No-spec Rationale

Bookkeeping archive plus SDD policy exemption for tool-managed lifecycle dirs; no module API or requirement deltas.
