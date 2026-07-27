---
id: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
state: archived
type: bug_fix
base_commit: d6bd453c7eeac1a686ffbd8bd299f5ca1033b801
---

# Prevent schema-controlled paths from deleting or escaping the APS state root for issue 111

## Intent

Prevent schema-controlled paths from deleting or escaping the APS state root for issue 111

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Unsafe root, directory, reserved, colliding, and symlinked schema paths are rejected; valid nested paths continue to work; reset and purge never recursively delete directories or escape the state root; adversarial regression tests and all cross-platform gates pass.

## No-spec Rationale

Not applicable
