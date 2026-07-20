---
change: CHG-0015-remove-unreachable-apserror-unknownkey-and-jsoncoding-decode-for-issue-15
artifact: context
---

# Context

Issue #15: `APSError.unknownKey` is unreachable (ArgumentParser rejects unknown keys first) and `JSONCoding.decode` is only used from production profile set plus dead test surface. Remove both and keep profile JSON parsing local to `StateStore.set(.profile)`.
