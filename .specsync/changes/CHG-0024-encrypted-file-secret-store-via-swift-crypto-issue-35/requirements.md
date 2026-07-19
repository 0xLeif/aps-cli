---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: requirements
---

# Requirements

- New REQ-aps-cli-020: encrypted-file secret store (construction, zero
  prompts, loud wrong-key and corrupt failures, tri-OS, no
  Security.framework imports).
- REQ-aps-cli-005 error coverage swaps the removed `keychainUnavailable`
  for `secretUnlockFailed`.
