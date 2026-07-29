---
change: CHG-0062-update-security-sensitive-site-dependencies-in-pr-108-and-verify-lint-hosting-b
artifact: context
---

# Context

Dependabot PR #108 updates the site build toolchain and transitive packages with
published security fixes. Its original branch predates the current release
candidate and failed Trust because the meaningful dependency files had no
covering SpecSync change.

This change preserves the existing PR, rebases it onto current `main`, and
records verification without changing the aps CLI or StateStore contracts.
