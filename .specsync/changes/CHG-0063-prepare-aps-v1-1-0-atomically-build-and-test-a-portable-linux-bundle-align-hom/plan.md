---
change: CHG-0063-prepare-aps-v1-1-0-atomically-build-and-test-a-portable-linux-bundle-align-hom
artifact: plan
---

# Plan

1. Correct Linux build ordering and add archive, rpath, clean-container, and
   installer contract tests.
2. Add a reviewed Homebrew template and render it from post-release
   automation with the portable archive checksum.
3. Add the repository version contract, update every 1.1.0 surface, and add a
   drift test plus release dry-run documentation.
4. Pin upstream 0x, replace local visual tokens, add the standard theme
   controller, and refine the aps-specific state-tape page.
5. Run site lint, builds, rendered-output tests, accessibility checks,
   version and distribution contracts, native verification, SpecSync, and
   Trust.
