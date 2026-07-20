---
change: CHG-0032-fix-linux-release-link-allow-shlib-undefined-for-libswiftobservation-on-6-0-x-t
artifact: testing
---

# Testing

- Root cause confirmed from the failed run log (run 29716075384): link error on libswiftObservation.so, Linux leg only.
- YAML syntax validated locally after the edit.
- `fledge lanes run verify` and `specsync change check` must pass on the PR.
- Live validation happens on the re-run of the Release backfill against v1.0.0 after merge (Linux leg links, release job attaches three binaries + sidecars).
