---
change: CHG-0063-prepare-aps-v1-1-0-atomically-build-and-test-a-portable-linux-bundle-align-hom
artifact: context
---

# Context

The v1.1.0 audit found three remaining release blockers. The Linux workflow
copies the executable before applying its portable runtime path, the Homebrew
automation still targets the retired non-archive asset, and version 1.0.0 is
duplicated across runtime and documentation contracts. The existing aps site
also maintains a local visual token system even though the `0xLeif/0x`
contribution fork of `tofu-ux/0x` now provides the intended shared tokens,
component styles, theme behavior, and Swift-adjacent identity.

This change deliberately lands these obligations together. A release must not
advertise 1.1.0 until its distribution channels agree, and the site should
describe that release using the shared design-system source requested by the
project owner.
