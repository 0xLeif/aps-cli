---
change: CHG-0027-preseed-fledge-with-curl-retries-in-trust-workflow-for-issue-39-ci-flake
artifact: docs
---

# Docs

## Updated

- `.github/workflows/trust.yml`: curl retries for SpecSync mirror assets; new step preseeds Fledge 1.7.0 into `${RUNNER_TEMP}/corvid-trust-fledge` with retries and checksum verification before the Trust action runs.
