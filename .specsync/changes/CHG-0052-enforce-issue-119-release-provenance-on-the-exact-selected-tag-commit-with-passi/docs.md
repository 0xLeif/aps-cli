---
change: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
artifact: docs
---

# Docs

- Add `docs/release-provenance.md` with the v1.1.0 guarantee, signing ceremony,
  backup and restore steps, compromise response, and key rotation.
- Link the runbook from README and the documentation index.
- Update release readiness to distinguish soft pull request provenance from the
  strict release-only publication gate.
- Avoid claiming that commit or tag signatures are checked: the enforced
  signature is the Ed25519 signature on the Attest record bound to the exact
  tag commit.
