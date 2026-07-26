---
change: CHG-0042-add-reusable-foreign-workflow-installer-action-for-release-binaries
artifact: context
---

# Context

Issue #84 asks for a reusable installer for workflows that do not have a Swift toolchain. The existing release workflow publishes standalone `aps` binaries for Linux x64 and both macOS architectures, each with a SHA-256 sidecar. A composite Action can consume those stable assets and expose the CLI while keeping state isolated to the GitHub job's temporary directory.
