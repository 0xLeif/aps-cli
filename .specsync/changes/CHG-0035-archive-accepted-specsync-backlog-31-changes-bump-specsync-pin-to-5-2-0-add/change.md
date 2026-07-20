---
id: CHG-0035-archive-accepted-specsync-backlog-31-changes-bump-specsync-pin-to-5-2-0-add
state: accepted
type: operations
base_commit: de318e247be0bc426d0a0db5e25945ba975facd3
---

# Archive accepted SpecSync backlog (31 changes), bump specsync pin to 5.2.0, add post-merge archive rule to AGENTS.md (issue 74)

## Intent

Archive accepted SpecSync backlog (31 changes), bump specsync pin to 5.2.0, add post-merge archive rule to AGENTS.md (issue 74)

## Affected Canonical Specs

- None

## Acceptance Criteria

- .specsync/changes/ holds no accepted merged changes; all 31 backlog changes live under .specsync/archive/changes/ with date prefixes; specsync pin is 5.2.0 across .specsync/version, trust.yml, and README; AGENTS.md standing rules include the post-merge archive step; specsync change check --strict and fledge lanes run verify pass

## No-spec Rationale

Bookkeeping archive of merged changes plus toolchain pin bump and agent rule; no module API or requirement deltas.
