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
APS_HOME="$PWD/.release-state" aps dump --json
APS_HOME="$PWD/.release-state" aps watch releasePhase --jsonl --timeout 300
```

aps records operational state. Signed provenance still belongs in Attest, the
release tag remains the version authority, and CI remains the test authority.
