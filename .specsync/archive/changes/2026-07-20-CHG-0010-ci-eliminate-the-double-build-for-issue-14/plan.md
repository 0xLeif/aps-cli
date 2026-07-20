# Plan

1. macOS CI: `swift test -c release` then smoke with `APS_BIN=.build/release/aps`
2. Linux smoke: drop standalone debug build; `swift test` produces the binary smoke uses
