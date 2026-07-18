---
change: CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38
artifact: context
---

# Context

Issue #38: AppState FileState writes are non-atomic. Concurrent `aps set` can tear JSON files, and AppState's initial() fallback masks that. `aps` must loud-fail on existing-but-undecodable files without changing AppState.
