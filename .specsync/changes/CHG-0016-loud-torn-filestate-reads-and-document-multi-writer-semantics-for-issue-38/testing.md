---
change: CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-005 | `testAPSErrorDescriptionsAreActionable` (`corruptState`) |
| REQ-aps-cli-017 | `testReadNoteFromDiskRejectsTornFile`, `testWatchSurfacesTornNoteFileAsCorruptState`, README section |
| REQ-state-store-004 | `testWatchSurfacesTornNoteFileAsCorruptState` |
| REQ-state-store-015 | `testReadNoteFromDiskIfPresentMissingIsNil`, `testReadNoteFromDiskRejectsTornFile`, `testReadProfileFromDiskRejectsTornFile` |

## Suites

- `swift test`
- `fledge lanes run verify`
