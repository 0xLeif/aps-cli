---
id: CHG-0027-preseed-fledge-with-curl-retries-in-trust-workflow-for-issue-39-ci-flake
state: archived
type: documentation
base_commit: df57539989daa26bb8d4e343ed47dbd18178b73d
---

# Preseed Fledge with curl retries in Trust workflow for issue 39 CI flake

## Intent

Preseed Fledge with curl retries in Trust workflow for issue 39 CI flake

## Affected Canonical Specs

- None

## Acceptance Criteria

- trust.yml preseeds Fledge 1.7.0 into RUNNER_TEMP/corvid-trust-fledge with curl retries and checksum verification; SpecSync mirror downloads also retry.

## No-spec Rationale

Workflow download resilience only; module contracts unchanged.
