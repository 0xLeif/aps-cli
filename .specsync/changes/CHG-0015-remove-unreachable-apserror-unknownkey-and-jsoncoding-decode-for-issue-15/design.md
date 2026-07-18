---
change: CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15
artifact: design
---

# Design

Keep `JSONCoding` as encode-only for dump pretty-printing. Profile set uses `JSONDecoder` directly and maps parse failures to `APSError.invalidValue`, matching prior behavior.
