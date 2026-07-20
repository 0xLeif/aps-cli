---
change: CHG-0032-fix-linux-release-link-allow-shlib-undefined-for-libswiftobservation-on-6-0-x-t
artifact: context
---

# Context

Issue #68 follow-up: the first v1.0.0 backfill run of the Release workflow failed on the Linux leg. Both macOS legs passed; the Linux executable link failed with `libswiftObservation.so: error: undefined reference to 'swift::threading::fatal'` on the Swift 6.0.3 Ubuntu toolchain. This is the same toolchain quirk linux-smoke.yml already documents and works around for `swift test` with `-Xlinker --allow-shlib-undefined`; the release executable link needs the same tolerance. Fix: pass `-Xlinker --allow-shlib-undefined` on the Linux build leg only (the flag is a GNU ld option and would break the macOS ld64 link, so it stays out of the shared path).
