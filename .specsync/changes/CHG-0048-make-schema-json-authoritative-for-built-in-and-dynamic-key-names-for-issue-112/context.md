---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: context
---

# Context

`schema.json` is documented as the live registry for both default seed keys and
user-added keys. The string-key API resolves a `SchemaKeyEntry`, but then
dispatches any name matching `DemoKey` through compile-time AppState adapters.
Those adapters hard-code type, storage, initial value, file path, Slice target,
watch behavior, and JSON output type.

As a result, `key add --force` can successfully replace a seed entry while
`get`, `set`, `reset`, `watch`, and `dump` continue using the old compiled
definition. Issue #112 makes the registry the single runtime authority.

`DemoKey` remains useful as the seed-name inventory and for low-level AppState
dogfooding tests. A name match alone must never select a runtime adapter for a
registry command.
