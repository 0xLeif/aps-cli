---
change: CHG-0025-aps-schema-self-describing-contract-endpoint-issue-32
artifact: context
---

# Context

Issue #32 (design decision 4). Agents need a self-describing endpoint to
discover the CLI contract and negotiate drift instead of guessing, and it
is the precondition for dynamic schema (1.0), where users define the keys.

## Decisions

- Static contract only; live state stays in `dump` (interview round 2).
- Integer `schemaVersion`, bumped on any contract change; agents compare
  equality and bail on mismatch. Document must be cacheable.
- One `Schema.document()` builder deriving keys from `DemoKey` metadata;
  commands/payloads/errors declared as static contract tables.
- Payload shapes use a minimal JSON Schema subset (type, properties,
  required, array/items) instead of full draft 2020-12.
