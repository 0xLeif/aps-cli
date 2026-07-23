---
change: CHG-0042-add-reusable-foreign-workflow-installer-action-for-release-binaries
artifact: design
---

# Design

The Action metadata delegates to a checked-in Bash installer for Linux and macOS, with a PowerShell error step for Windows. The installer maps GitHub runner labels to the release asset names from the release workflow, validates a strict semantic version, downloads both files with curl retries, checks the digest using `shasum`, and atomically promotes the verified binary. GitHub environment files provide PATH and environment changes to later steps.
