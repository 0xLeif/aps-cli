---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: research
---

# Research

The authority bypasses are in `StateStore+Registry.get(name:)`,
`set(name:value:)`, `reset(name:)`, `requireDecodableDiskState(forName:)`, and
`watchBlocking(name:)`, plus `CLIOutput.typedValue(for:from:)`.

The compiled adapters bind `flag` to AppState's `App/aps.flag` UserDefaults
identity, while dynamic StoredState uses `aps.user.<name>`. Default FileState
and EncryptedFile wire paths already match their schema entries. Dynamic Slice
reads and writes the parent declared by the registry and therefore replaces
the hard-coded `profileName` path cleanly.

Polling-only registry watch remains correct across all storage kinds and is
required for cross-process FileState and StoredState changes. Removing the
DemoKey observation fast path may trade immediate in-process wakeups for the
configured polling interval, without changing observable values or stop
semantics.
