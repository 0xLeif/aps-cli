---
change: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
artifact: plan
---

# Plan

1. Define a release-only Attest policy with a pinned reviewer identity and
   public key.
2. Add a reusable exact-tag provenance gate and deterministic contract tests.
3. Route tag pushes and manual backfills through the gate, then propagate the
   resolved SHA through testing, building, and publication.
4. Document the guarantee and operational recovery procedures.
5. Update the canonical aps-cli requirement and testing evidence.
6. Run the release contract tests, `fledge lanes run verify`, strict SpecSync
   checks, and SpecSync change verification.
