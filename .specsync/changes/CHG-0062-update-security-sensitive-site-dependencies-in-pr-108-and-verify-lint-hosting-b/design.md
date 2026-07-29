---
change: CHG-0062-update-security-sensitive-site-dependencies-in-pr-108-and-verify-lint-hosting-b
artifact: design
---

# Design

Keep the dependency update lockfile-driven and scoped to `site/package.json`
and `site/package-lock.json`. Do not change application behavior or weaken SDD
coverage. Validate both supported hosting outputs:

- GitHub Pages static export and its exported-path assertions.
- Cloudflare/Vinext production output and rendered HTML assertions.

Use the committed npm lockfile as the reproducibility boundary. Confirm the
production dependency graph has no reported vulnerabilities after installation.
