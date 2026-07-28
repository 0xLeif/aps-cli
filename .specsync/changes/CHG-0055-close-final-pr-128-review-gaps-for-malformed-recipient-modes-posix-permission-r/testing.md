---
change: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
artifact: testing
---

# Testing

## Requirement evidence

| Requirement | Evidence |
| --- | --- |
| REQ-aps-cli-032 | Missing/null mode, post-read widening, and pinned-root regressions in `SecretStoreSecurityTests` and `SecureKeyFileTests` |
| REQ-state-store-025 | `SecretStoreSecurityTests.testRegisteredEncryptedWatchPinsInitialCanonicalStateRoot` plus the existing descendant-symlink replacement regression |

- Missing and null version 2 modes return `decodingFailed` with zero KDF calls.
- Unknown non-null modes retain `unsupportedSecretEnvelope`.
- A deterministic hook widens a POSIX key to `0644` after reading; load rejects
  it as `insecurePermissions` and preserves exact bytes.
- A registered encrypted watch observes target A, the configured root symlink
  retargets to target B, and later polls remain beneath target A.
- `fledge lanes run verify` passes 238 serial and 238 parallel tests, smoke,
  CI dogfood, installer contract, and plugin validation.
- Hosted macOS, Ubuntu, Linux, Windows, and Trust gates pass.
