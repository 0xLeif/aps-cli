# aps-cli v1.1.0 release contract

## MODIFIED

### REQUIREMENT REQ-aps-cli-013

The CLI `--version` string SHALL be `1.1.0`.

Acceptance Criteria
- `aps --version` prints `1.1.0`.
- `aps schema` `cliVersion` equals `1.1.0`.

## ADDED

### REQUIREMENT REQ-aps-cli-037

APS release preparation SHALL synchronize one reviewed semantic version across
runtime help, schema output, tests, smoke scripts, canonical requirements,
plugin metadata, README, release documentation, and the product site. A
deterministic repository check SHALL fail when any declared version surface
drifts.

The Linux release artifact SHALL be
`aps-linux-x86_64-portable.tar.gz`. Its executable SHALL contain
`$ORIGIN/lib`, and its sibling `lib/` directory SHALL contain the Swift runtime
libraries needed to run without an installed Swift toolchain. Release,
installer, checksum, and Homebrew contracts SHALL use the same asset name and
archive layout. Homebrew SHALL preserve the executable beside `lib/` under
`libexec` and expose a wrapper from `bin`.

The product site SHALL consume the commit-pinned `0xLeif/0x` contribution
fork, credit `tofu-ux/0x` upstream, implement its dark-first no-flash theme
contract, and retain aps-specific Swift state and command examples.

Acceptance Criteria
- Every declared product-version surface reports 1.1.0.
- A deliberate version mismatch fails the version-contract test.
- The archived Linux executable passes runtime-path inspection, checksum and
  installer extraction tests, and execution in Linux without Swift installed.
- Formula generation emits matching portable URLs, checksums, and a
  `libexec` bundle install.
- The site uses upstream 0x tokens and components, exposes an accessible
  theme toggle, and passes both hosting builds and rendered-output tests.
- The release dry run targets v1.1.0 without unexpected edits.
