---
change: CHG-0063-prepare-aps-v1-1-0-atomically-build-and-test-a-portable-linux-bundle-align-hom
artifact: testing
---

# Testing

- Release workflow contract test asserts final build ordering, runtime-path
  inspection, clean-container execution, and installer extraction.
- Formula rendering test checks all three URLs and checksums plus the Linux
  `libexec` layout.
- Version contract test checks every declared 1.1.0 surface and a negative
  drift fixture.
- Swift build, serial tests, parallel tests, smoke, CI dogfood, installer
  contract, provenance contract, and plugin validation run through Fledge.
- Site `npm ci`, lint, Pages build, Vinext build, rendered HTML tests, and
  accessibility audit pass.
- `specsync change check --strict`, configured change verification, and
  `fledge trust verify --range origin/main...HEAD` pass.

## Evidence

| Requirement | Evidence |
|---|---|
| REQ-aps-cli-013 | `Scripts/test-version-contract.sh`, `APSTests.testSchemaDocumentCoversAllKeysAndCommands`, and both smoke scripts verify 1.1.0 runtime and schema output. |
| REQ-aps-cli-037 | Release distribution, installer, formula rendering, version drift, 0x vendor, Pages, Vinext, and AXE contract tests cover the complete release-preparation surface. |

- `fledge lanes run verify`: 11 steps passed, including 159 serial and 266
  parallel tests, smoke, CI dogfood, installer, release distribution, version
  drift, 0x vendor, provenance, and plugin contracts.
- Site lint, Pages export, Vinext rendered HTML, and AXE checks passed for dark
  desktop, light desktop, and dark mobile.
