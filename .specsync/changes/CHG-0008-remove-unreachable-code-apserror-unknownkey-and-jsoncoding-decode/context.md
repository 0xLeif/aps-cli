---
change: CHG-0008-remove-unreachable-code-apserror-unknownkey-and-jsoncoding-decode
artifact: context
---

# Context: Remove Unreachable Code

`APSError.unknownKey` was exported in the spec and defined in code but never thrown in any source file, only used in a test to verify the error type exists.

`JSONCoding.decode` was a generic helper that provided minimal value over direct use of `JSONDecoder`. It was used in `StateStore` for `ProfileDocument` decoding.

Removing these simplifies the public API and removes dead code without altering behavior.