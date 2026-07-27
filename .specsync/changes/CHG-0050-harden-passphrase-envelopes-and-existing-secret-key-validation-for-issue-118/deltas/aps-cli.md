# aps-cli hardened secret envelopes

## ADDED

### REQUIREMENT REQ-aps-cli-030

APS encrypted-file secrets SHALL use a strict, versioned recipient contract.
Every new write SHALL produce a v2 envelope whose `recipientMode` is exactly
`passphrase` or `keyFile`. Passphrase envelopes SHALL derive a 32-byte X25519
private key with public CryptoExtras scrypt using a fresh cryptographically
random 16-byte salt and exactly `N=131072`, `r=8`, `p=1`. The persisted KDF
object SHALL record `algorithm: "scrypt"`, `rounds: 131072`, `blockSize: 8`,
`parallelism: 1`, and `outputByteCount: 32`. Key-file envelopes SHALL omit
`kdf`.

APS SHALL validate the exact top-level and KDF JSON shapes, canonical base64,
decoded cryptographic field lengths, version, mode, algorithm, salt length,
and numeric KDF constants before invoking scrypt, key agreement, or decryption.
Unknown versions or recipient modes SHALL fail as
`unsupportedSecretEnvelope`; malformed fields or mode/KDF combinations SHALL
fail as `decodingFailed`. Neither failure SHALL invoke attacker-selected KDF
work. APS SHALL never fall back between v2 recipient modes.

Acceptance Criteria
- New passphrase envelopes record version 2, passphrase mode, the fixed scrypt
  profile, and a fresh 16-byte salt.
- Repeated writes with the same passphrase and plaintext produce distinct salts
  and ciphertext and both round-trip.
- New key-file envelopes record key-file mode and omit KDF metadata.
- Unsupported versions and modes fail with `unsupported_secret_envelope` at
  exit 65 before KDF work.
- Invalid KDF values, duplicate or unknown fields, malformed base64, and wrong
  decoded lengths fail with `decoding_failed` at exit 65 before KDF work.
- Wrong credentials and recipient-mode mismatch fail with
  `secret_unlock_failed` at exit 69 without changing envelope or key-file bytes.
- Unprovable key-file ownership, type, or privacy fails with
  `insecure_secret_key_file` at exit 77 without replacing the path.
- The implementation uses apple/swift-crypto `4.0.0..<4.4.0` and the public
  `CryptoExtras` product on macOS, Linux, and Windows. The upper bound preserves
  the Swift 6.0 tools floor because swift-crypto 4.4+ requires Swift tools 6.1.
- Documentation publishes the exact KDF profile, approximately 128 MiB memory
  cost, compatibility behavior, and platform key-file requirements without
  promising crash atomicity or guaranteed memory zeroization.
