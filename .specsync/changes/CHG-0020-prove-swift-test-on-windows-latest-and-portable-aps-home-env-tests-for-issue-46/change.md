---
id: CHG-0020-prove-swift-test-on-windows-latest-and-portable-aps-home-env-tests-for-issue-46
state: accepted
type: feature
base_commit: 7571e11d1f4da488f9540b0175420f69501814e1
---

# Prove swift test on windows-latest and portable APS_HOME env tests for issue 46

## Intent

Prove swift test on windows-latest and portable APS_HOME env tests for issue 46

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- windows-smoke.yml runs swift test then smoke.ps1 on windows-latest; APSPaths env test uses portable setProcessEnv; docs/README updated.

## No-spec Rationale

Not applicable
