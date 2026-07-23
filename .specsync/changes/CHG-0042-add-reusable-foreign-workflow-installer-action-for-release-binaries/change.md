---
id: CHG-0042-add-reusable-foreign-workflow-installer-action-for-release-binaries
state: accepted
type: feature
base_commit: 644ea11c8d735f2c85dd708366611b81298c8818
---

# Add reusable foreign-workflow installer Action for release binaries

## Intent

Add reusable foreign-workflow installer Action for release binaries

## Affected Canonical Specs

- None

## Acceptance Criteria

- The composite Action selects the release asset for supported GitHub-hosted macOS and Linux runner architectures, verifies its SHA-256 sidecar before installation, adds the executable directory to PATH, defaults APS_HOME under RUNNER_TEMP without overwriting an explicit APS_HOME, and documents/test these behaviors. fledge lanes run verify and Action tests pass.

## No-spec Rationale

This change adds a GitHub composite Action and user-facing workflow documentation; it does not change the Swift runtime or any canonical Swift API contract.
