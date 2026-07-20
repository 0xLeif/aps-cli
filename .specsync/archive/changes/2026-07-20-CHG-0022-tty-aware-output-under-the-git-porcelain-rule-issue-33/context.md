---
change: CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33
artifact: context
---

# Context

Issue #33 (design decision 5, minimal chrome from round 2). aps emitted
plain text and always-pretty JSON everywhere; humans got no polish and
piped agents paid multi-line token cost. The contract must be: human
output may be pretty, machine output is frozen.

## Decisions

- Git porcelain rule: human output may evolve; machine shapes are
  additive-only contracts.
- Minimal chrome: aligned `keys` table, bold headers, semantic color
  honoring NO_COLOR; richer styling deferred.
- JSON pretty on TTY, compact when piped (gh rule), applied via
  `CLIOutput.encodeJSON` and `JSONCoding.encodeAuto` (dump keeps the
  injected dependency).
- Flag symmetry: `watch --json` aliases `--jsonl`; `keys --quiet` prints
  names only.
