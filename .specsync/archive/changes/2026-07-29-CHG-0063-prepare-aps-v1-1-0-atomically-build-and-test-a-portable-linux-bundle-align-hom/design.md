---
change: CHG-0063-prepare-aps-v1-1-0-atomically-build-and-test-a-portable-linux-bundle-align-hom
artifact: design
---

# Design

## Release distribution

Build the Linux executable once with the final linker arguments, inspect it,
then copy that exact file into the archive. Generate a temporary checksum and
run the repository installer against a local release URL. A clean Ubuntu
container executes the extracted bundle, proving it does not rely on an
installed Swift toolchain.

The repository owns a Homebrew formula template. Post-release automation
renders version and checksums into that reviewed structure instead of mutating
an unknown live formula shape.

## Version preparation

`VERSION` is the reviewed release-preparation input. A deterministic script
sets or checks every intentional duplicate. The check runs in the normal
Fledge verification lane so future drift fails before release.

## Product site

The site vendors `0xLeif/0x` commit
`26fb2108a0e4c8ba65c06f1d70983e7dce298112` through a deterministic Contents
API sync command and committed SHA-256 manifest. The fork is the collaboration
surface for contributions, while `tofu-ux/0x` remains its credited upstream.
The site imports generated 0x tokens and components and implements the standard
`0x-theme` pre-paint and toggle contract.

The visual thesis remains the live state tape: Swift declarations flow into a
terminal mutation and observable state transition. Righteous carries the
product voice, IBM Plex Mono carries commands and facts, cyan is the primary
signal, and fuchsia is reserved for mutation. No gradients or locally
re-derived theme colors are introduced.
