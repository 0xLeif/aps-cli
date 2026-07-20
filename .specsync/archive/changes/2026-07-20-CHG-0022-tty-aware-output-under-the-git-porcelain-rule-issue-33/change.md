---
id: CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33
state: archived
type: feature
base_commit: c4ecd60b2a46bca4780f1b4af79a1d495d646287
---

# TTY-aware output under the git porcelain rule (issue 33)

## Intent

TTY-aware output under the git porcelain rule (issue 33)

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- TTY output is human-pretty (aligned keys table with bold header, semantic color honoring NO_COLOR) while piped output stays byte-stable plain (TSV, no ANSI); JSON is pretty on TTY and compact when piped for dump and all --json payloads; watch --json aliases --jsonl; keys --quiet prints names only; completion scripts documented; machine shapes additive-only; tests and smoke assert all of it.

## No-spec Rationale

Not applicable
