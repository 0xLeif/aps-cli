---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: plan
---

# Plan

1. Add the shared schema-storage path value and unit tests.
2. Enforce portable lexical rules, reserved paths, and complete-schema
   collision checks.
3. Route dynamic FileState, EncryptedFile, reset, and purge operations through
   canonical runtime resolution.
4. Replace recursive schema-controlled deletion with verified leaf deletion.
5. Add adversarial CLI and smoke coverage for root aliases, directories,
   symbolic links, collisions, reserved files, and valid nested paths.
6. Update canonical requirements and public safety documentation.
7. Run the native verification lane, SpecSync verification, and Trust.
