---
change: CHG-0008-remove-unreachable-code-apserror-unknownkey-and-jsoncoding-decode
artifact: testing
---

# Testing

- Verified that `APSError.unknownKey` and `JSONCoding.decode` are no longer used in source.
- Confirmed that `StateStore` profile decoding still works as expected.
- Ran all tests via `fledge lanes run verify` and all passed.
- Verified that specs match the new source structure.