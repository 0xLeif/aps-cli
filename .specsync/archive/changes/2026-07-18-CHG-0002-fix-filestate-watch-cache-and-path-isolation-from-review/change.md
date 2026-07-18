---
id: CHG-0002-fix-filestate-watch-cache-and-path-isolation-from-review
state: archived
type: feature
base_commit: c6d9326fd7f4c7925deb5ff4f27f984a073bf6b8
---

# Fix FileState watch cache and path isolation from review

## Intent

Fix FileState watch cache and path isolation from review

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- watch note sees cross-process file writes; StateStore preserves injected FileState paths; set note fails when disk write does not persist; specs/README match; 20 tests pass

## No-spec Rationale

Not applicable
