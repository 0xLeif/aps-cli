---
change: CHG-0001-adopt-corvidlabs-trust-toolchain-for-the-private-aps-cli
artifact: design
---

# Design

Keep a standard Trust profile with soft provenance. Commit module specs for aps-cli and state-store as canonical companions. CI and Trust workflows both use runs-on: [self-hosted, macOS]. fledge lanes.verify runs build, test, and smoke.
