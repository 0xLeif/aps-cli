---
id: CHG-0017-add-fledge-plugin-toml-shim-and-validate-in-verify-lane-for-issue-37
state: implementing
type: documentation
base_commit: d0e158325efb5006efcb4a2ed7ae1e9f4b43ef39
---

# Add fledge plugin.toml shim and validate in verify lane for issue 37

## Intent

Add fledge plugin.toml shim and validate in verify lane for issue 37

## Affected Canonical Specs

- None

## Acceptance Criteria

- plugin.toml declares fledge-plugin-aps v0.2.0 with aps -> .build/release/aps; fledge plugins validate runs in verify lane; README documents live-link install and fledge aps keys --json.

## No-spec Rationale

Docs and fledge plugin manifest only; CLI contracts unchanged.
