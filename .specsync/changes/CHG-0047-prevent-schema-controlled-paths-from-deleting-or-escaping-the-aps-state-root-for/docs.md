---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: docs
---

# Docs

Update the dynamic-schema design and README path guidance to state that
persistent paths are portable relative regular-file paths under the state root.
Document rejected root aliases, reserved APS paths, collisions, directories,
and symbolic links. Do not claim protection against an attacker with concurrent
write access to the state-root filesystem beyond operation-time validation.
