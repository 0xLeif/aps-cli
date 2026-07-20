---
change: CHG-0028-implement-dynamic-schema-registry-and-public-ready-1-0-0-prep-for-issues-62-64
artifact: research
---

# Research

RFC locked in CHG-0026 / issue #39. Seed keys keep AppState DemoKey bindings; user keys
use DynamicKeyStorage. Schema write failures map to persistenceFailed (exit 73) so the
unwritable-root smoke contract holds when materialization is the first write.
