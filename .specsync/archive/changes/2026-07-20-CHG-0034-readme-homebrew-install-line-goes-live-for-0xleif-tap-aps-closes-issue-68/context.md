---
change: CHG-0034-readme-homebrew-install-line-goes-live-for-0xleif-tap-aps-closes-issue-68
artifact: context
---

# Context

Issue #68 closeout: the distribution pipeline is live and verified (v1.0.0 carries aps-macos-aarch64, aps-macos-x86_64, aps-linux-x86_64 with sha256 sidecars; Formula/aps.rb seeded in 0xLeif/homebrew-tap; the post-release sync no-op'd cleanly; brew install 0xLeif/tap/aps and brew test aps pass locally). The README Install section still says the tap is in progress. This change flips it to lead with the working brew command.
