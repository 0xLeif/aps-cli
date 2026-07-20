---
change: CHG-0031-release-workflow-building-tri-platform-binaries-with-sha256-sidecars-plus-post
artifact: plan
---

# Plan

1. `.github/workflows/release.yml`: test gate (`swift build` + `swift test` on macos-latest against the tagged ref), build matrix (macos-latest arm64 + x86_64 via `--arch`, ubuntu-latest x86_64 via swift-actions/setup-swift 6.0), checksum sidecars, `softprops/action-gh-release` attach. Dispatch input `tag` targets an existing release for backfill.
2. `.github/workflows/post-release-formula.yml`: mirrors CorvidLabs/fledge's post-release-formula.yml (workflow_run on Release success for v* tags, plus dispatch recovery). Resolves the tag (semver-validated), downloads the three `.sha256` sidecars (format-validated), rewrites version + shas in Formula/aps.rb via python, pushes to the tap, and polls the Contents API until the formula reports the new version. Requires a TAP_GITHUB_TOKEN repo secret (contents:write on 0xLeif/homebrew-tap).
3. After merge: add the TAP_GITHUB_TOKEN secret (repo admin step), run Release via dispatch with tag=v1.0.0 to backfill assets, seed Formula/aps.rb in the tap with the real shas, verify `brew install 0xLeif/tap/aps`, then flip the README install line (follow-up to #67).
