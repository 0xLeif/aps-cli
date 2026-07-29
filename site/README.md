# aps site

The product and documentation site for [aps](https://github.com/0xLeif/aps-cli).

## Local development

```bash
bun install
bun run dev
```

Open `http://localhost:3000`.

## Validate

```bash
bun run build
bun run build:pages
bun test
bun run test:a11y
bun run lint
```

The default build uses vinext and remains deployable through the repository's
Sites configuration. `npm run build:pages` creates a static export in `out/`
with the `/aps-cli` project base path. The Pages workflow validates site changes
on pull requests and deploys that static artifact after a push to `main`.

Product claims should remain aligned with the root README,
`docs/release-readiness.md`, and the SpecSync contracts.

## Design system

The site consumes the pinned [`0xLeif/0x`](https://github.com/0xLeif/0x)
contribution fork of [`tofu-ux/0x`](https://github.com/tofu-ux/0x). The
vendored snapshot provides cyan and fuchsia semantic tokens, the Righteous and
IBM Plex Mono type system, accessible components, and standard theme behavior.

Run `fledge run ox-update` to stage and atomically replace the complete pinned
snapshot. Review and update the pinned revision in `Scripts/sync-0x.sh` when
adopting upstream work from tofu.

The signature element is the state tape: a typed value moving through an
observable state transition. Keep that motif specific to state changes rather
than using it as decoration.
