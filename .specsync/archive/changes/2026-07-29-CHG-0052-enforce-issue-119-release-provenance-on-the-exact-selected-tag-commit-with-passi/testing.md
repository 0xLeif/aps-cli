---
change: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
artifact: testing
---

# Testing

| Requirement | Evidence |
|---|---|
| REQ-aps-cli-036 | `Scripts/test-release-provenance.sh` creates isolated repositories and proves missing-note, failed-tests, unsigned, invalid-signature, and untrusted-key records fail while valid pinned signed evidence passes. |
| REQ-aps-cli-036 | The same contract test validates production policy semantics, strict SemVer parsing, exact-one-commit merge ranges, both release triggers, immutable action pinning, non-persisted checkout credentials, exact-SHA checkouts, the release Environment, default-branch reachability, and pre/post-publication tag-binding checks. |
| REQ-aps-cli-036 | `fledge lanes run verify` exercises build, Swift tests, smoke tests, CI dogfood, installer contract, and the release provenance contract. |

Verification commands:

```sh
./Scripts/test-release-provenance.sh
fledge lanes run verify
fledge spec check --strict
specsync change check --strict
```
