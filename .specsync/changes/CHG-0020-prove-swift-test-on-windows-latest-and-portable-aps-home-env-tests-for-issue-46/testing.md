---
change: CHG-0020-prove-swift-test-on-windows-latest-and-portable-aps-home-env-tests-for-issue-46
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-018 | `testAPSPathsResolveOrder`, `.github/workflows/windows-smoke.yml` (`swift test` + smoke.ps1), `specs/aps-cli/testing.md` |

## Suites

- Local: `swift test`
- CI: `windows-smoke` workflow
