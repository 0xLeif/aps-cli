---
id: CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38
state: archived
type: feature
base_commit: c0c5b4bfb7c712506f9795c80889f03094596629
---

# Loud torn FileState reads and document multi-writer semantics for issue 38

## Intent

Loud torn FileState reads and document multi-writer semantics for issue 38

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Torn note/profile files throw corruptState (exit 65); watch --jsonl emits error event; missing files stay nil/initial; README documents single-writer last-writer-wins; tests cover ifPresent and watch.

## No-spec Rationale

Not applicable
