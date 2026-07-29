---
change: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
artifact: context
---

# Context

The repository says releases carry signed provenance, but the only checked
policy is intentionally permissive: `.trust.toml` selects soft provenance and
`.attest.json` does not require an attestation, passing tests, or a signature.
The release workflow tests and builds a tag, but it does not verify the tag
commit's Attest note before publishing artifacts.

Pull requests must remain usable for contributors who do not hold a release
signing key. Release publication has a stronger trust boundary: both a normal
`v*` tag event and an operator-triggered backfill can attach public artifacts.
Both paths therefore need the same fail-closed gate on the exact selected tag
commit.
