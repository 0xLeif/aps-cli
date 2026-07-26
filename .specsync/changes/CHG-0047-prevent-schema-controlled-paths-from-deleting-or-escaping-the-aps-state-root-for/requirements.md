---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: requirements
---

# Requirements

1. Persistent schema paths shall be portable relative file paths beneath the
   canonical state root.
2. Validation shall reject root aliases, absolute paths, empty or traversal
   components, backslashes, reserved APS paths, directories, symbolic links,
   special files, and case-insensitive path collisions.
3. Runtime resolution shall re-check canonical containment and existing path
   components before reading, writing, resetting, or purging data.
4. Schema-controlled deletion shall operate only on a verified regular leaf
   file. A missing file is a successful no-op; a directory, symbolic link, or
   special file is an error and remains unchanged.
5. Valid nested paths shall remain supported on macOS, Linux, and Windows.
6. Concurrent schema additions claiming the same portable path shall not both
   succeed.
