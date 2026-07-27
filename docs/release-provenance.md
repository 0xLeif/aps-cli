# Release provenance

The v1.1.0 release workflow is designed to publish artifacts only when the
exact selected tag commit passes the release-only Attest policy. This applies
to both a normal `v*` tag push and a manual artifact backfill.

## Enforced guarantee

`.attest-release.json` requires the selected commit to have:

- an Attest record in `refs/notes/attest`;
- passing-test evidence;
- a cryptographically valid Ed25519 signature;
- reviewer identity `human:leif`;
- the public key pinned to that identity in the policy.

The signature covers the Attest record bound to the commit. This is not a claim
that the Git commit or Git tag itself has a GPG or SSH signature.

The workflow resolves the tag to one full commit SHA, confirms that it is
reachable from the default branch, and verifies only that one commit even when
it is a merge. Tests and all platform builds check out that SHA. Immediately
before upload, the workflow refreshes the tag from origin, verifies that it
still names the same SHA, and re-runs the signed-evidence policy. Missing notes,
failed-test evidence, unsigned records, invalid signatures, untrusted keys, and
moved tags all stop publication.

Manual backfills run the gate script and policy from the current default branch,
so a historical target tag does not need to contain those control-plane files.
The historical tag commit still needs a conforming signed Attest note before
its artifacts can be rebuilt.

Ordinary branch and pull request workflows remain usable without the release
key. `.attest.json` and `.trust.toml` intentionally keep soft provenance for
those workflows; `.attest-release.json` is the stricter publication boundary.
The provenance, test, and build jobs receive a read-only repository token.
Only the final publication job receives `contents: write`.

The repository must also configure two GitHub-hosted controls:

- a protected `v*` tag ruleset that limits tag creation, update, and deletion
  to the release owner;
- a `release` Environment with the release owner as a required reviewer, no
  administrator bypass, and deployment policies for both `v*` tags and the
  protected default branch used by manual backfills.

The workflow declares `environment: release`, so publishing pauses at that
review boundary when the Environment is configured. The tag ruleset is a
repository setting and cannot be created by workflow YAML. Do not tag v1.1.0
until both controls have been inspected in repository settings. Confirm the
default-branch deployment policy with a dry manual dispatch before relying on
backfill recovery.

These controls and the owner account's ability to administer workflows, rules,
environments, and `contents: write` credentials are external trust roots. A
repository administrator or compromised write credential can still change
those controls. The workflow re-fetches and verifies the remote tag after
upload to detect a concurrent move, but GitHub does not offer an atomic
"verify tag and publish assets" operation. If the final check fails, treat the
release as suspect and remove or quarantine its assets before retrying.

## Release ceremony

From a clean checkout of the commit intended for the tag:

```bash
fledge lanes run verify
fledge trust verify

commit="$(git rev-parse HEAD)"
git fetch origin "+refs/notes/attest:refs/notes/attest"
attest sign \
  --commit "$commit" \
  --reviewer human:leif \
  --confidence 1 \
  --verdict proceed \
  --tests-passed \
  --human-approved \
  --sign \
  --note "v1.1.0 release gate"

attest verify --commit "$commit" --policy .attest-release.json
git push origin refs/notes/attest
git tag -a v1.1.0 "$commit" -m "aps 1.1.0"
git push origin v1.1.0
```

Do not create or push the tag until the note is present on the exact commit and
the strict verification command passes. Never commit the private key.

## Backup and recovery

The primary portable record is `refs/notes/attest`. Push it explicitly after
signing and mirror it with the release tag:

```bash
git fetch origin "+refs/notes/attest:refs/notes/attest"
git bundle create aps-v1.1.0-provenance.bundle \
  refs/notes/attest refs/tags/v1.1.0
attest export --commit "$(git rev-list -n 1 v1.1.0)" \
  > aps-v1.1.0-provenance.json
```

Store the bundle, audit export, and an encrypted backup of the private signing
key in separate access-controlled locations. The JSON export is audit evidence,
not a restorable Git note.

To recover notes into a clean clone:

```bash
git fetch /secure/backup/aps-v1.1.0-provenance.bundle \
  refs/notes/attest:refs/notes/attest
git notes --ref=attest show "$(git rev-list -n 1 v1.1.0)"
attest verify --commit "$(git rev-list -n 1 v1.1.0)" \
  --policy .attest-release.json
git push origin refs/notes/attest
```

Inspect and verify locally before pushing a restored notes ref. A manual
backfill uses the same gate as a tag push and is the supported way to rebuild
missing assets after recovery. This includes v1.0.0, but only after its exact
commit receives evidence accepted by the current release policy.

## Compromise response

If the private key may be exposed:

1. Stop tag creation and manual backfills.
2. Preserve the current notes ref, workflow logs, and release audit export for
   incident review.
3. Generate a new key on a trusted machine.
4. Replace both `trustedKeys` and `signerPinning.human:leif` in
   `.attest-release.json` through a reviewed pull request.
5. Sign new release evidence only after the policy change reaches main.
6. Do not backfill an older tag whose embedded policy still trusts the
   compromised key. Review and replace that release through an explicit
   incident plan.

Deleting a note does not make already downloaded artifacts disappear. If
published artifacts are suspect, remove them from the GitHub release, notify
users, rotate the release, and publish a replacement version.

## Planned key rotation

For non-emergency rotation, back up and verify the old notes first, generate the
new key, and land one reviewed policy change that atomically replaces both the
`trustedKeys` entry and `signerPinning.human:leif`. Use the new key only after
that change reaches the protected default branch.

Adding both keys to `trustedKeys` does not create a usable overlap for the same
identity because `signerPinning.human:leif` accepts only one key. A deliberate
overlap requires a distinct temporary reviewer identity, its own pinned key,
and both identities in `allowedReviewers`. Remove the temporary identity and
old key in a reviewed follow-up before another release.

The repository currently pins one key and one identity. Changing reviewer
identity, adding a second release operator, choosing a hardware-backed or
offline key location, and defining escrow access are owner security decisions,
not workflow defaults.
