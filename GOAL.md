# aps 1.0.0: dynamic schema + public-ready dogfood harness

## Goal

Ship a private 1.0.0 release candidate with a registry-backed `schema.json`,
`aps key add|remove|list`, dynamic `aps schema` projection, and GitHub-hosted
tri-OS CI, then execute the go-public checklist on release day.

## Why now

- 0.2.0 completed the fixed-key agent dogfood surface.
- The dynamic schema RFC is accepted (`docs/design/dynamic-schema.md`, #39).
- Public 1.0.0 should not require a self-hosted macOS runner for PRs.

## Success criteria (prep, this pass)

- [x] Default `schema.json` materializes under the state root.
- [x] `get` / `set` / `reset` / `dump` / `keys` / `watch` resolve string registry names.
- [x] `aps key add|remove|list` mutates the registry with stable error codes.
- [x] `aps schema` projects live keys + `userSchema.hash`; `schemaVersion` is 3.
- [x] Smoke covers materialize + key add/remove on shell and PowerShell.
- [x] macOS CI and Trust run on `macos-latest` (Linux/Windows smokes unchanged).
- [x] Version strings and docs say **1.0.0**.

## Explicitly deferred to release day ([#40](https://github.com/0xLeif/aps-cli/issues/40))

- Flip repository visibility to public
- Add `fledge-plugin` topic and `fledge plugins publish`
- Decommission self-hosted runner `aps-cli-mac-arm64`
- Cut GitHub Release / tag `v1.0.0`
- Post-public Trust re-verify on the public repo

## Tickets

| ID | Item |
|----|------|
| #62 | Schema file IO + validation + materialization |
| #63 | Registry resolve + `aps key add/remove/list` |
| #64 | Dynamic `aps schema` + smoke |
| #40 | Go public + cut 1.0.0 (release day) |

## Definition of done (prep)

Dynamic schema implemented and smoked tri-OS; CI/Trust on GitHub-hosted runners;
docs/version at 1.0.0; #40 left for the explicit public flip.
