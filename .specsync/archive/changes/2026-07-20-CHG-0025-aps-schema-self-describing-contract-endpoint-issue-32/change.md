---
id: CHG-0025-aps-schema-self-describing-contract-endpoint-issue-32
state: archived
type: feature
base_commit: 8cf886df7ac87eac4234fc3fb8c13f46362e08d6
---

# Aps schema self-describing contract endpoint (issue 32)

## Intent

aps schema self-describing contract endpoint (issue 32)

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- aps schema emits one cacheable JSON document: cliVersion (equals aps --version), integer schemaVersion (bumped on contract change), state-root precedence, every DemoKey with type/storage/lifetime/path, every subcommand with flags and payload refs, payload JSON shapes, and the stable error table with exit codes. Static contract only; tests assert coverage and validity; smoke greps schemaVersion and checks cliVersion equals --version.

## No-spec Rationale

Not applicable
