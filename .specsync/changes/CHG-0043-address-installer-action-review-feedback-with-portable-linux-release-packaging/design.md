---
change: CHG-0043-address-installer-action-review-feedback-with-portable-linux-release-packaging
artifact: design
---

# Design

The release workflow packages Linux `aps` with the Swift/Foundation/Observation shared libraries under `lib/` and links with `$ORIGIN/lib`, producing `aps-linux-x86_64-portable.tar.gz`. The Action verifies the archive checksum, extracts it into the job temp install root, and preserves the existing macOS executable path. Version validation accepts SemVer prerelease and build metadata and uses `v<version>` as the release tag. The Action contract script becomes a fledge verify step.
