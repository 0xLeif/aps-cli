---
change: CHG-0042-add-reusable-foreign-workflow-installer-action-for-release-binaries
artifact: requirements
---

# Requirements

1. The composite Action SHALL derive the release version from its pinned Action ref by default and SHALL accept an explicit semantic-version `version` input.
2. The installer SHALL select only Linux/X64, macOS/X64, or macOS/ARM64 release assets.
3. The installer SHALL download the binary and adjacent `.sha256` sidecar over HTTPS, validate the sidecar shape, and compare the SHA-256 digest before installation.
4. The installer SHALL download into a temporary `.part` file and move it into `${RUNNER_TEMP}/aps/bin/aps` only after verification, with executable permissions.
5. The installer SHALL append the binary directory to `GITHUB_PATH` and SHALL set `APS_HOME` through `GITHUB_ENV` to `${RUNNER_TEMP}/aps-home` only when the caller did not already set `APS_HOME`.
6. Unsupported runners, missing `RUNNER_TEMP`, invalid versions, malformed sidecars, and checksum mismatches SHALL fail with an actionable error.
