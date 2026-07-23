---
id: CHG-0043-address-installer-action-review-feedback-with-portable-linux-release-packaging
state: accepted
type: bug_fix
base_commit: 8e2108601b182584e59b3e534b67199247593a0a
---

# Address installer Action review feedback with portable Linux release packaging, SemVer support, and CI coverage

## Intent

Address installer Action review feedback with portable Linux release packaging, SemVer support, and CI coverage

## Affected Canonical Specs

- None

## Acceptance Criteria

- README uses an Action ref containing action.yml and passes an explicit release version; the release workflow publishes a Linux bundle containing aps and Swift runtime libraries with an $ORIGIN/lib rpath; the installer accepts SemVer prerelease/build suffixes and extracts the verified bundle; the installer contract test runs in fledge verify; strict SpecSync and fledge verification pass.

## No-spec Rationale

This review-fix change updates CI packaging, the reusable Action, its docs, and test wiring; it does not change Swift runtime code or a canonical Swift API.
