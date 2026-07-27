---
change: CHG-0048-make-schema-json-authoritative-for-built-in-and-dynamic-key-names-for-issue-112
artifact: plan
---

# Plan

1. Remove every name-based `DemoKey` branch from registry operations and typed
   output.
2. Make seed bulk reset intersect seed names with the current registry and
   dispatch through current entries.
3. Preserve the unchanged default flag through a narrow legacy StoredState
   fallback while keeping `aps.user.<name>` canonical.
4. Add unit and subprocess coverage for forced seed type, storage, path,
   initial value, Slice metadata, watch behavior, and typed output.
5. Update the dynamic-schema design, README, and both canonical specs.
6. Run native verification, SpecSync verification, Trust, and all platform CI.
