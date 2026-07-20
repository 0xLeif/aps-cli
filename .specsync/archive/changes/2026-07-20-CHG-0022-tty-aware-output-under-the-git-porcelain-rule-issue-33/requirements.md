---
change: CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33
artifact: requirements
---

# Requirements

- New REQ-aps-cli-019: TTY-aware output under the git porcelain rule
  (TTY pretty, piped byte-stable plain; JSON pretty on TTY, compact when
  piped; flag symmetry; completion docs).
- state-store spec: `dump` and `JSONCoding` documents gain the TTY-aware
  `encodeAuto` behavior.
