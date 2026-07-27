---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: requirements
---

# Requirements

1. Every CLI string-key operation shall use the current resolved
   `SchemaKeyEntry`, including when the key name is part of the default seed
   inventory.
2. A forced seed replacement shall control runtime type, storage, path, initial
   value, object shape, Slice parent and field, watch source, and machine output
   typing wherever those fields apply.
3. Name-based `DemoKey` dispatch shall not override a registry entry.
4. Seed bulk reset shall target only seed names that remain in the current
   registry and shall reset them through their current entries.
5. Forced storage or path changes shall not implicitly migrate, purge, or read
   data belonging to the former adapter or path.
6. The unchanged default StoredState flag shall remain readable from its legacy
   AppState key when no canonical dynamic value exists. Reset shall prevent the
   legacy value from reappearing.
7. Default materialized schema behavior shall remain compatible for seeded
   FileState, EncryptedFile, Slice, and primitive values.
