---
change: CHG-0032-fix-linux-release-link-allow-shlib-undefined-for-libswiftobservation-on-6-0-x-t
artifact: tasks
---

# Tasks

- [x] Add `-Xlinker --allow-shlib-undefined` to the Linux leg of the Build release binary step in `.github/workflows/release.yml`, with a comment citing the linux-smoke.yml precedent.

Follow-up (outside this change): after merge, re-dispatch the Release workflow with tag=v1.0.0 and confirm all three binaries + sha256 sidecars attach to the v1.0.0 release (tracked on issue #68).
