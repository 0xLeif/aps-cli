# Release pipeline

This example records an observable local release checkpoint:

```bash
APS_HOME="$PWD/.release-state" \
RELEASE_VERSION=1.1.0 \
CANDIDATE_COMMIT="$(git rev-parse HEAD)" \
./examples/release-pipeline/run.sh
```

The state root records the candidate version and commit, current phase, latest
test result, and risk verdict. A release script, agent, or terminal dashboard
can inspect it with:

```bash
APS_HOME="$PWD/.release-state" ./examples/release-pipeline/run.sh
APS_HOME="$PWD/.release-state" "${APS_BIN:-aps}" watch releasePhase --jsonl --timeout 300
```

aps records operational state. Signed provenance still belongs in Attest, the
release tag remains the version authority, and CI remains the test authority.
Changing the release version or candidate commit resets `releasePhase` to
`planned`, `releaseTestsPassed` to `false`, and `riskVerdict` to `pending`.
Provide new phase and gate results only after evaluating that candidate.
