---
change: CHG-0025-aps-schema-self-describing-contract-endpoint-issue-32
artifact: design
---

# Design

- New `Sources/aps/Schema.swift`: `Schema.document()` returns a
  `Document` (cliVersion, schemaVersion, stateRoot precedence, keys,
  commands, payloads, errors) encoded via `CLIOutput.encodePretty`.
- New `schema` subcommand (`SchemaCmd`) prints the document; `--json`
  accepted as a no-op for agent symmetry (same rule as `dump`).
- `cliVersion` is a constant asserted against `aps --version` in smoke,
  guarding drift without refactoring the version declaration.
- Error table mirrors the APSError taxonomy (including `corrupt_state`
  from the multi-writer work) as static content.
