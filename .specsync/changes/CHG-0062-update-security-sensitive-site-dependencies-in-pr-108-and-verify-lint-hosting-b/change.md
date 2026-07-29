---
id: CHG-0062-update-security-sensitive-site-dependencies-in-pr-108-and-verify-lint-hosting-b
state: accepted
type: operations
base_commit: 3f2bc4febce1d28a85c9fde41b610263cbbcf63e
---

# Update security-sensitive site dependencies in PR 108 and verify lint, hosting builds, rendered output, and production audit

## Intent

Update security-sensitive site dependencies in PR 108 and verify lint, hosting builds, rendered output, and production audit

## Affected Canonical Specs

- None

## Acceptance Criteria

- PR 108 is rebased onto current main; Vite, Cloudflare tooling, fast-uri, js-yaml, undici, and ws security updates are installed from the committed lockfile; site lint, GitHub Pages build and export test, Cloudflare build and rendered HTML test, and production dependency audit pass; hosted Trust passes without bypassing SpecSync.

## No-spec Rationale

Dependency resolution and vulnerability remediation do not change the normative aps CLI or StateStore contracts.
