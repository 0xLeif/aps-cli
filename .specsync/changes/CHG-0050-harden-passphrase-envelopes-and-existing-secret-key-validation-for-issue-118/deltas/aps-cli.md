# aps-cli hardened secret envelopes

## ADDED

### REQUIREMENT REQ-aps-cli-030

APS encrypted-file secrets SHALL use a strict, versioned recipient contract.
Every new write SHALL produce a v2 envelope whose `recipientMode` is exactly
`passphrase` or `keyFile`. Passphrase envelopes SHALL derive the 32-byte X25519
recipient key with public CryptoExtras scrypt using a fresh random 16-byte salt
and exactly `N=131072`, `r=8`, `p=1`. Key-file envelopes SHALL contain no
password-KDF descriptor.

APS SHALL validate the complete JSON shape, mode, KDF name and parameters,
base64 data, and cryptographic field lengths before invoking scrypt, key
agreement, or decryption. Unsupported versions, unknown or duplicate fields,
invalid mode/KDF combinations, and noncanonical KDF values SHALL fail as
`APSError.decodingFailed` without attacker-selected KDF work. APS SHALL never
fall back between v2 recipient modes.

Acceptance Criteria
- A new passphrase envelope records `version=2`,
  `recipientMode=passphrase`, scrypt, a random 16-byte salt, `N=131072`,
  `r=8`, `p=1`, and 32 output bytes.
- Two writes with the same plaintext and passphrase use distinct salts and
  ciphertext and both decrypt successfully.
- A new key-file envelope records `recipientMode=keyFile` and omits `kdf`.
- Unsupported versions, modes, KDFs, parameters, duplicate or unknown keys,
  malformed base64, and wrong decoded lengths fail before the KDF runs.
- Wrong credentials retain `secretUnlockFailed`, do not select another
  recipient mode, and leave envelope and key-file bytes unchanged.
- The implementation uses apple/swift-crypto `4.0.0..<4.4.0` and the public
  CryptoExtras product on macOS, Linux, and Windows.
- Production contains no force try or force cast.
- README and security documentation publish the exact KDF parameters,
  approximately 128 MiB memory cost, compatibility behavior, and key-file
  ownership and privacy requirements without claiming crash atomicity or
  guaranteed memory zeroization.

