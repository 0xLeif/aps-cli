---
change: CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38
artifact: plan
---

# Plan

1. Add `APSError.corruptState` + exit code 65.
2. Split disk reads into ifPresent (nil / value / corrupt) vs require-present.
3. Make `watchBlocking` / CLI get throw on corrupt; jsonl emits error event.
4. Document multi-writer semantics in README; tests + SpecSync.
