---
change: CHG-0035-archive-accepted-specsync-backlog-31-changes-bump-specsync-pin-to-5-2-0-add
artifact: context
---

# Context

Issue #74: 31 accepted SpecSync changes (CHG-0003 through CHG-0034) sat in `.specsync/changes/` because nothing in the merge routine ever ran `specsync change archive`. The naive sweep failed on two preflights: (1) the coverage guard needs an empty delivery diff vs origin/main, so a bundled sweep must simulate integration between per-archive checkpoint commits; (2) the historical-integrity guard in specsync 5.1.1 cannot authenticate acceptance evidence that was refreshed on squash-merged feature branches, which is this repo's exact workflow. spec-sync v5.2.0 (released 2026-07-20) ships anchor logic for that squash-merged re-verification shape plus regression tests, so this change also bumps the pin: `.specsync/version`, the trust.yml mirror version + step, and the README lines. AGENTS.md gains the post-merge archive standing rule so the backlog does not regrow. Archive moves were produced by the pinned binary (5.2.0) with per-archive checkpoint commits and local origin/main integration simulation, exactly matching the upstream test `archive_waits_until_delivery_diff_no_longer_needs_coverage`.
