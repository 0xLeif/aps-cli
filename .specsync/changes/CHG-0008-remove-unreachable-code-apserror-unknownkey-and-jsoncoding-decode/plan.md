---
change: CHG-0008-remove-unreachable-code-apserror-unknownkey-and-jsoncoding-decode
artifact: plan
---

# Plan

1. Remove `APSError.unknownKey` from `Sources/aps/DemoKey.swift`.
2. Remove `decode` method from `JSONCoding` in `Sources/aps/Dependencies.swift`.
3. Update `Sources/aps/StateStore.swift` to use `JSONDecoder` directly for `ProfileDocument` decoding.
4. Remove tests exercising `APSError.unknownKey` in `Tests/apsTests/APSTests.swift`.
5. Update specifications:
   - Remove `unknownKey` from `specs/aps-cli/requirements.md`.
   - Remove `unknownKey` from `specs/aps-cli/aps-cli.spec.md`.
   - Remove `decode` from `specs/state-store/state-store.spec.md`.
6. Verify via `fledge lanes run verify`.