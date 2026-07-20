---
change: CHG-0024-encrypted-file-secret-store-via-swift-crypto-issue-35
artifact: docs
---

# Docs

README replaces the SecureState/Keychain section with "Encrypted-file
secret store (`secret`)": construction, key file vs passphrase modes,
TTY opt-in prompt, reset semantics, and the rationale for replacing
Keychain (prompt per access; AppState unchanged, SecureState dogfood
moves to AppStateExamples). Demo-keys table and AppState coverage matrix
updated; GOAL.md secret bullet and docs/windows-readiness.md rows updated.
