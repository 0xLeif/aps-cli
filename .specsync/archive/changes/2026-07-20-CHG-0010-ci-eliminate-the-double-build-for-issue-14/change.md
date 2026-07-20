---
id: CHG-0010-ci-eliminate-the-double-build-for-issue-14
state: archived
type: operations
base_commit: 778676002ccdf9bbc6646fd2435644a902f73801
---

# CI: eliminate the double build for issue 14

## Intent

CI: eliminate the double build for issue 14

## Affected Canonical Specs

- None

## Acceptance Criteria

- macOS CI runs a single release configuration (swift test -c release then smoke against .build/release/aps); Linux smoke runs swift test then smoke against the debug binary without a separate prior build step.

## No-spec Rationale

CI workflow-only change; no module API or CLI contract changes.
