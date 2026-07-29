---
id: CHG-0064-fix-release-workflow-fetch-authentication-so-signed-tags-and-attest-notes-can-be
state: implementing
type: bug_fix
base_commit: 7373d124ebb3823c1f7f19651dfffe4d7ed83f51
---

# Fix release workflow fetch authentication so signed tags and attest notes can be fetched on GitHub-hosted runners

## Intent

Fix release workflow fetch authentication so signed tags and attest notes can be fetched on GitHub-hosted runners

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Release fetches use one checkout-managed credential, the release distribution contract rejects manual duplicate Authorization headers, and a v1.1.0 workflow dispatch passes provenance.

## No-spec Rationale

This repairs CI authentication plumbing without changing the aps CLI contract or release artifact semantics.
