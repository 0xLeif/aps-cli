---
change: CHG-0030-docs-readme-install-section-and-post-1-0-refresh-dynamic-schema-rfc-seed-examp
artifact: context
---

# Context

Issue #67: v1.0.0 shipped and the repo is public, but the README has no install section and still carries pre-release lines. This change adds a working Install section (fledge plugin hub, Mint, source build; Homebrew tap noted as in progress under #68), points the fledge plugin shim at the published hub repo, refreshes the GOAL.md trust-table row and Next goal section for shipped 1.0.0, and replaces stray em/en dashes per the standing rules. It also aligns docs/design/dynamic-schema.md with the shipped runtime: the seed schema.json example now lists all 7 demo keys from UserSchema.defaultDocument (message and flag were missing) and the status line records implementation in PR #65. Docs-only; no runtime or canonical spec deltas.
