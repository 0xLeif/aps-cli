---
change: CHG-0016-loud-torn-filestate-reads-and-document-multi-writer-semantics-for-issue-38
artifact: design
---

# Design

Missing file: fall back to AppState get/initial. Existing undecodable file: `corruptState` (never silent initial). CLI maps that to stderr + `ExitCode(65)`. No AppState or file-locking changes.
