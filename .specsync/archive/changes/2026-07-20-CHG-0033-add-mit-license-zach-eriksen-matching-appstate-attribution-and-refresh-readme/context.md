---
change: CHG-0033-add-mit-license-zach-eriksen-matching-appstate-attribution-and-refresh-readme
artifact: context
---

# Context

Issue #72: aps-cli has no LICENSE file, which surfaced while seeding the Homebrew formula for #68 (the formula's license field stays out until the repo declares one). The project is 0xLeif's personal work, so the copyright line matches 0xLeif/AppState: `Copyright (c) 2026 Zach Eriksen`. While here, the README layout block gets two stale entries fixed: LICENSE is added, and the workflow glob now lists all six workflows (release.yml and post-release-formula.yml landed with #70 after the block was last updated).
