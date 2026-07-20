---
change: CHG-0035-archive-accepted-specsync-backlog-31-changes-bump-specsync-pin-to-5-2-0-add
artifact: plan
---

# Plan

1. Archive the backlog: `specsync change archive` (5.2.0 binary) for CHG-0003 through CHG-0034, with checkpoint commits + local `refs/remotes/origin/main` updates between archives so the coverage preflight sees an integrated delivery diff.
2. Bump the pin 5.1.1 to 5.2.0: `.specsync/version`, trust.yml (mirror VERSION, specsync-version input, step names/comments), README (requirements line, trust table row).
3. AGENTS.md multi-agent rules: new standing rule to archive the SpecSync change from a clean main-based checkout after the implementing PR merges, noting the empty-diff preflight and the 5.2.0 requirement.
4. Verify: `specsync change check --strict` and `fledge lanes run verify`; PR; after merge, archive CHG-0035 itself as the first execution of the new routine.
