---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: docs
---

# Docs

- [x] README: document `key add --field`, structural object machine output,
  explicit Slice field contracts, and schema version 6 metadata.
- [x] `docs/design/dynamic-schema.md`: replace the deferred recursive-object note,
  define recursive JSON and open shape semantics, and document invalid-schema
  compatibility behavior.
- [ ] `docs/release-readiness.md`: close issue #114 only after hosted gates pass.
- [x] Canonical aps-cli spec: key-add UX, lossless machine values, `keyCount`, and
  schema version 6.
- [x] Canonical state-store spec: centralized type/shape enforcement and explicit
  Slice invariants.
- [x] Unix and PowerShell smoke comments explain the new shaped-object contract.
