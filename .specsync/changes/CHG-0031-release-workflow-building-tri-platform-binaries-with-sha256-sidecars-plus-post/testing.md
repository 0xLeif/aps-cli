---
change: CHG-0031-release-workflow-building-tri-platform-binaries-with-sha256-sidecars-plus-post
artifact: testing
---

# Testing

- YAML syntax validated locally for both workflows.
- `fledge lanes run verify` (build + test + smoke + plugin-validate) must pass with the workflows present.
- `specsync change check` clean; rebind sweep for any stale exact-only evidence.
- Post-merge live test (recorded on issue #68): dispatch Release with tag=v1.0.0, confirm three binaries + sidecars attach to the v1.0.0 release, then dispatch Post-Release Formula Update and confirm Formula/aps.rb lands at 1.0.0 with matching shas; `brew install 0xLeif/tap/aps` and `aps --version` on macOS arm64.
- Workflow logic hazards checked by review: macOS bash 3.2 (no empty-array expansion), attacker-controlled contexts flow through env blocks only, sha256 values regex-validated before use.
