# aps-cli authoritative live registry

## ADDED

### REQUIREMENT REQ-aps-cli-028

Every CLI operation accepting a registered key name SHALL derive runtime
behavior and machine output from that key's current `SchemaKeyEntry`, including
when the name belongs to the default seed inventory. Name-based `DemoKey`
dispatch SHALL NOT override the live registry.

Acceptance Criteria
- Forced seed replacements control get, set, reset, watch, dump, and typed
  machine output.
- `reset --all` targets registered seed names through their current entries and
  does not recreate removed seed names.
- Storage or path replacement does not implicitly migrate or delete old data.
- Default seeded behavior remains compatible after schema materialization.
