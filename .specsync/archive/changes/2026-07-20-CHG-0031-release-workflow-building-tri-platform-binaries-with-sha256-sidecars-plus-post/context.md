---
change: CHG-0031-release-workflow-building-tri-platform-binaries-with-sha256-sidecars-plus-post
artifact: context
---

# Context

Issue #68: the repo is public and v1.0.0 is tagged, but the release has zero binary assets, so no install path exists beyond building from source. CorvidLabs/homebrew-tap already ships binary formulas for the other CorvidLabs tools (Formula/fledge.rb pattern: per-platform url + sha256, bin.install, test block). This change ports that distribution pipeline to aps: a tag-triggered Release workflow that builds the Swift binary for macOS arm64 + x86_64 (via `swift build --arch` on macos-latest, no Intel runner) and Linux x86_64, attaches binaries with sha256 sidecars to the GitHub release, and a post-release workflow that rewrites Formula/aps.rb in 0xLeif/homebrew-tap with the new version and real shas. Both workflows carry a workflow_dispatch recovery lever so v1.0.0 assets can be backfilled and a failed formula sync can be retried without cutting a new tag. Formula/aps.rb itself is seeded in the tap repo separately once assets exist; the automation only rewrites version + sha256 lines thereafter.
