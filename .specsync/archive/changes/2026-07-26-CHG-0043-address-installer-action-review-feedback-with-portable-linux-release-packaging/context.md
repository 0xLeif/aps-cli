---
change: CHG-0043-address-installer-action-review-feedback-with-portable-linux-release-packaging
artifact: context
---

# Context

PR #104 review found four gaps in the initial installer: the README referenced a tag that predates the Action, the existing Linux executable required Swift shared libraries, the version parser rejected valid release suffixes, and the Action test was not in the verify lane. This change closes those gaps while preserving the Swift runtime scope.
