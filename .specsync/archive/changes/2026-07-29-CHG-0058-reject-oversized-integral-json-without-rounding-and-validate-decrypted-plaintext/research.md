---
change: CHG-0058-reject-oversized-integral-json-without-rounding-and-validate-decrypted-plaintext
artifact: research
---

# Research

JSONDecoder fails Int decoding for an oversized integer and may then decode the
same token as a rounded Double. An integral Double with no exact Int conversion
therefore identifies the unsafe fallback. Existing encrypted registered reads
already centralize schema enforcement in `validateReadValue`.
