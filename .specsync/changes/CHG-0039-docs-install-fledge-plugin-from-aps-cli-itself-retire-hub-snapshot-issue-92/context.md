---
change: CHG-0039-docs-install-fledge-plugin-from-aps-cli-itself-retire-hub-snapshot-issue-92
artifact: context
---

# Context

Issue #92: aps-cli carries its own root plugin.toml and passes `fledge plugins validate .`, so the repo itself is the fledge plugin and `fledge plugins install 0xLeif/aps-cli` is the complete install path. The separate hub snapshot repo (0xLeif/fledge-plugin-aps, created on go-public day) is duplication that can only go stale; it already lagged main once and had to be hand-refreshed over SSH. This change points every install instruction at aps-cli and marks the hub snapshot retired in the docs. Deleting the hub repo remains a separate owner decision.
