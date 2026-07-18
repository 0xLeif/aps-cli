---
change: CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15
artifact: plan
---

# Plan

1. Remove `APSError.unknownKey` and its description branch.
2. Remove `JSONCoding.decode`; inline profile JSON decode in `StateStore.set(.profile)`.
3. Drop the unknownKey unit assertion.
4. Update aps-cli / state-store specs and MODIFIED deltas; verify with `fledge lanes run verify`.
