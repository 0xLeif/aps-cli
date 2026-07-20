---
change: CHG-0027-preseed-fledge-with-curl-retries-in-trust-workflow-for-issue-39-ci-flake
artifact: context
---

# Context

PR #56 Trust failed twice on `curl: (18) Transferred a partial file` while Trust v1.0.1 downloaded Fledge 1.7.0. Preseed the binary into Trust's known install root with retries so the gate skips the flaky download.
