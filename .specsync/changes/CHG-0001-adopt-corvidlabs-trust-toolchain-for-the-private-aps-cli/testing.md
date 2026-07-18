---
change: CHG-0001-adopt-corvidlabs-trust-toolchain-for-the-private-aps-cli
artifact: testing
---

# Testing

Local: fledge lanes run verify, swift test, Scripts/smoke.sh, fledge trust doctor. CI: CI workflow smokes the release binary; Trust workflow runs CorvidLabs/trust@v1 and greps AGENTS.md markers.
