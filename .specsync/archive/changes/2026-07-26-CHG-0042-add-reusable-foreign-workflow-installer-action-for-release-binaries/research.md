---
change: CHG-0042-add-reusable-foreign-workflow-installer-action-for-release-binaries
artifact: research
---

# Research

The release workflow names assets `aps-macos-aarch64`, `aps-macos-x86_64`, and `aps-linux-x86_64`, and writes one SHA-256 file beside each asset. GitHub hosted runner labels expose `runner.os` values `Linux`, `macOS`, and `Windows`, and architecture values `X64` and `ARM64`.
