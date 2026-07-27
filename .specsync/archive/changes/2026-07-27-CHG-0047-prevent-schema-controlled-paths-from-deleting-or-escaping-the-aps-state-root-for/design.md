---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: design
---

# Design

Add an internal `SchemaStoragePath` value that validates wire-compatible
`String` paths, produces a portable collision key, resolves paths beneath a
canonical state-root URL, and removes only verified regular files.

Lexical validation rejects `.`, empty and traversal components, platform
absolute forms, backslashes, control characters, trailing dot/space
components, Windows device names, APS internal files, and the lock namespace.
Complete-document validation rejects duplicate collision keys.

Runtime resolution canonicalizes the state root, resolves every existing
ancestor, proves containment by URL path components, and rejects symbolic-link
or non-regular leaves. All dynamic FileState and EncryptedFile adapters resolve
through this type instead of appending raw schema strings.

Schema mutation remains protected by `SchemaFileLock`; complete-document
validation therefore serializes collision checks. This patch does not claim
descriptor-relative protection against a hostile process racing filesystem
components after validation.
