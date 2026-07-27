---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: docs
---

# Docs

Update the dynamic-schema design and README to state that `schema.json` is the
runtime authority for default and user-added names. Document that `DemoKey`
only defines the initial seed inventory, that `--force` changes subsequent
runtime behavior without migrating or deleting old adapter data, and that seed
bulk reset honors the current registered definitions.

Document the legacy default-flag read fallback and the canonical
`aps.user.<name>` StoredState namespace.
