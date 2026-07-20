---
id: CHG-0031-release-workflow-building-tri-platform-binaries-with-sha256-sidecars-plus-post
state: accepted
type: operations
base_commit: c6e416a38d36064608db0f7f5c7e6adaec01a0c3
---

# Release workflow building tri-platform binaries with sha256 sidecars, plus post-release Homebrew tap formula sync targeting 0xLeif/homebrew-tap (issue 68)

## Intent

Release workflow building tri-platform binaries with sha256 sidecars, plus post-release Homebrew tap formula sync targeting 0xLeif/homebrew-tap (issue 68)

## Affected Canonical Specs

- None

## Acceptance Criteria

- Tag push or dispatch builds aps-macos-aarch64, aps-macos-x86_64, and aps-linux-x86_64 with sha256 sidecars and attaches them to the GitHub release; post-release workflow syncs version+shas into 0xLeif/homebrew-tap Formula/aps.rb

## No-spec Rationale

CI/release automation only; no module API or requirement deltas.
