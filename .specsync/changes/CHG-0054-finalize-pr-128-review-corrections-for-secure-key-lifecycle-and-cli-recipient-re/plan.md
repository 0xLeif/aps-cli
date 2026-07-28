---
change: CHG-0054-finalize-pr-128-review-corrections-for-secure-key-lifecycle-and-cli-recipient-re
artifact: plan
---

# Plan

1. Unify repair-capable key loading under the store transaction lock.
2. Canonicalize and validate POSIX state roots without mutating their modes.
3. Add stable permission-repair error mapping.
4. Revalidate key-file recipients for changed watch snapshots.
5. Remove redundant encrypted CLI reads while preserving output behavior.
6. Correct canonical requirements and testing documentation.
7. Add focused regressions and run the complete verification lane.
