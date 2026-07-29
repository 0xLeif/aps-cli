# GitHub Actions

[`workflow.yml`](workflow.yml) is a complete two-job example:

1. Install the signed aps v1.1.0 release without installing Swift.
2. Create persistent CI keys and upload the state root.
3. Download the root in a dependent job.
4. Rediscover the schema and read the typed state.

Copy it into `.github/workflows/aps-state.yml` in another repository.

Use native `GITHUB_OUTPUT` for one or two scalar outputs. aps is useful when a
job needs a discoverable schema, several evolving values, local
cross-process reads, or a state snapshot that humans and agents can inspect.

All Actions are pinned to reviewed commit SHAs. The example uploads no
encrypted values. Do not upload both an encrypted envelope and its key file as
a public artifact.
