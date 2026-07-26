---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: research
---

# Research

Audited schema-controlled filesystem access in `UserSchema`,
`DynamicKeyStorage`, `StateStore+Registry`, and `SecretStore`.

The critical path is `SchemaKeyEntry.path` to
`URL.appendingPathComponent` to recursive `FileManager.removeItem`. Lock names
currently derive from only the leaf basename, so nested paths can also alias
one lock. Fixed internal paths include `schema.json`, schema lock files,
`secret.key`, secret lock files, and built-in seed storage files.

Foundation URL standardization and symbolic-link resolution are available on
all supported platforms. Portable lexical rejection is still required because
a schema authored on a case-sensitive platform may later be used on Windows.
