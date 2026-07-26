# aps-cli safe persistent schema paths

## ADDED

### REQUIREMENT REQ-aps-cli-027

Persistent FileState and EncryptedFile schema paths SHALL be portable relative
regular-file paths contained beneath the canonical state root. APS SHALL reject
root aliases, absolute or traversing paths, reserved internal paths,
directories, symbolic links, special files, and portable path collisions.

Acceptance Criteria
- `.` and `./` cannot be registered and cannot delete the state root.
- APS internal schema, key, and lock paths cannot be registered.
- Paths that collide case-insensitively cannot coexist in one schema.
- Valid nested relative paths continue to support get, set, reset, and purge.
- A rejected reset or purge preserves the target and returns a nonzero error.
