---
change: CHG-0062-update-security-sensitive-site-dependencies-in-pr-108-and-verify-lint-hosting-b
artifact: testing
---

# Testing

- `npm ci`: passed with the committed npm lockfile.
- `bun run lint`: passed.
- `bun run build:pages`: passed, including the exported-path test.
- `bun run test`: passed, including the Vinext build and rendered HTML test.
- `npm audit --omit=dev`: passed with zero production vulnerabilities.
- `specsync change check --strict`
- `fledge lanes run verify`
- `fledge trust verify`

The full development audit retains four moderate findings from Drizzle Kit's
deprecated internal esbuild loader and one high advisory chain in older
Minimatch consumers used only by lint tooling. npm proposes breaking
downgrades, and a forced Brace Expansion override breaks ESLint at runtime.
The supported graph is therefore retained until upstream packages migrate.
