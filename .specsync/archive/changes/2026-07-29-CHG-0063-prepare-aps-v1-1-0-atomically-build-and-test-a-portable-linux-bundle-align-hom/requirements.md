---
change: CHG-0063-prepare-aps-v1-1-0-atomically-build-and-test-a-portable-linux-bundle-align-hom
artifact: requirements
---

# Requirements

1. The archived Linux executable must contain `$ORIGIN/lib` before it is
   copied into the bundle.
2. CI must inspect the runtime path, verify the checksum, exercise installer
   extraction, and execute the bundle in Linux without a Swift toolchain.
3. Release, installer, formula template, and formula automation must name the
   same portable Linux archive and preserve its `aps` plus `lib/` layout.
4. Homebrew must install the portable bundle under `libexec` and expose `aps`
   through a generated wrapper so `$ORIGIN/lib` remains valid.
5. A repository `VERSION` contract and one preparation command must keep every
   declared product-version surface synchronized.
6. Runtime help, schema output, smoke tests, unit tests, specs, plugin
   metadata, README, release docs, and the product site must agree on 1.1.0.
7. The aps site must consume the commit-pinned `0xLeif/0x` contribution fork,
   credit `tofu-ux/0x` upstream, use its tokens and theme behavior, and retain
   aps-specific state examples.
8. The site must remain responsive, keyboard accessible, reduced-motion safe,
   compatible with static Pages export and Vinext hosting, and free of
   hardcoded local theme colors.
