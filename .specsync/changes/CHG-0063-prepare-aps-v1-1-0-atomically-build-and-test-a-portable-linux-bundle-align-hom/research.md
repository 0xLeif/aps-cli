---
change: CHG-0063-prepare-aps-v1-1-0-atomically-build-and-test-a-portable-linux-bundle-align-hom
artifact: research
---

# Research

- The existing release workflow copied `$BIN_DIR/aps` before rebuilding with
  the final `$ORIGIN/lib` runtime path.
- The installer already expects
  `aps-linux-x86_64-portable.tar.gz`, but post-release formula automation and
  the live tap formula still use `aps-linux-x86_64`.
- A Linux Homebrew formula cannot move only the executable into `bin` because
  its runtime path expects `lib/` beside the real executable. Installing the
  bundle under `libexec` and using `bin.write_exec_script` preserves it.
- `tofu-ux/0x` and `0xLeif/0x` currently resolve to the same commit. The npm
  package name exists in the manifest but is not published in the registry.
  Direct Git and codeload transport were unavailable locally, so the reviewed
  integration consumes `0xLeif/0x` through the authenticated Contents API plus
  committed hashes and retains `tofu-ux/0x` as the credited upstream.
- 0x requires generated tokens, Righteous plus IBM Plex Mono, dark-first theme
  behavior, the `0x-theme` storage key, an icon-only accessible toggle, and no
  gradients.
