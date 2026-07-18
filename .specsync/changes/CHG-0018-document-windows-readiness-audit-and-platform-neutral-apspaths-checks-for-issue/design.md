---
change: CHG-0018-document-windows-readiness-audit-and-platform-neutral-apspaths-checks-for-issue
artifact: design
---

# Design

Docs-only audit plus an internal `APSPaths.isDefaultAPSHomePath` helper so default-home tests do not assume Unix `/` separators. Windows CI stays deferred to #40.
