---
id: CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15
state: approved
type: refactor
base_commit: cb05f64c650260c5f3960b192d3be70c0e450627
---

# Remove unreachable APSError.unknownKey and JSONCoding.decode for issue 15

## Intent

Remove unreachable APSError.unknownKey and JSONCoding.decode for issue 15

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- APSError.unknownKey and JSONCoding.decode are removed; specs no longer list them; profile set still parses JSON; fledge lanes run verify passes.

## No-spec Rationale

Not applicable
