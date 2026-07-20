---
change: CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33
artifact: plan
---

# Plan

1. Add TTY.swift (detection, Style, table).
2. Add encodeJSON / encodeAuto and switch all JSON call sites including
   dump (via the injected JSONCoding).
3. keys: table on TTY, TSV when piped, --quiet.
4. watch: --json alias for --jsonl.
5. Tests (table alignment, style identity off-TTY, compact JSON) and
   smoke (piped-plain assertions, alias, quiet, compact greps).
6. Specs (both modules) and README in the same change.
