---
change: CHG-0043-address-installer-action-review-feedback-with-portable-linux-release-packaging
artifact: research
---

# Research

The current release workflow builds Linux with Swift 6.0 and publishes only a bare executable, so its Swift shared-library dependencies are absent on a stock runner. A self-contained archive with an `$ORIGIN/lib` rpath matches the existing build environment without requiring a consumer Swift toolchain. Release tags accept `v*`, so the Action must preserve SemVer suffixes after adding the `v` prefix.
