---
change: CHG-0045-refresh-project-documentation-and-add-the-swift-themed-aps-product-site
artifact: docs
---

# Docs

## Updated

- `README.md`: product promise, current status, security caveats, corrected
  concurrency language, and the next-release goal.
- `GOAL.md`: links the shipped 1.0 record to the next hardening phase.
- `docs/design/dynamic-schema.md`: distinguishes implemented behavior from
  invariants still requiring hardening.
- `docs/windows-readiness.md`: replaces the pre-public audit with the current
  source-CI and binary-distribution matrix.

## Added

- `docs/README.md`: documentation map and mental model.
- `docs/release-readiness.md`: evidence, release blockers, and candidate proof.
- `site/`: product site, social preview, validation, and hosting metadata.

No normative aps-cli or state-store requirement changes in this documentation
change. Future implementation work for the recorded blockers requires its own
SpecSync changes.
