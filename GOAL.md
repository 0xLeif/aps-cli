# aps 1.0.0: shipped

## Goal

Public 1.0.0 with a registry-backed `schema.json`, GitHub-hosted tri-OS CI, and a published fledge plugin shim.

## Done

- [x] Dynamic schema runtime (`schema.json`, `aps key`, dynamic `aps schema`)
- [x] GitHub-hosted CI/Trust (`macos-latest` / `ubuntu-latest` / `windows-latest`)
- [x] Version/docs at 1.0.0
- [x] Repo public; `fledge-plugin` topic
- [x] Self-hosted runner `aps-cli-mac-arm64` removed
- [x] GitHub Release [v1.0.0](https://github.com/0xLeif/aps-cli/releases/tag/v1.0.0)
- [x] Plugin hub repo [0xLeif/fledge-plugin-aps](https://github.com/0xLeif/fledge-plugin-aps)

## Install

```bash
git clone https://github.com/0xLeif/aps-cli.git
cd aps-cli && swift build -c release
# or via fledge:
fledge plugins install https://github.com/0xLeif/fledge-plugin-aps.git
```
