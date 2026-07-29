---
change: CHG-0062-update-security-sensitive-site-dependencies-in-pr-108-and-verify-lint-hosting-b
artifact: research
---

# Research

The dependency update includes security releases for `fast-uri`, `js-yaml`,
`undici`, and `ws`, plus compatible Vite, Wrangler, and Cloudflare plugin
versions. The update remains within the existing major-version constraints and
does not introduce a new runtime dependency for the Swift CLI.

Verification must cover both hosting targets because the site uses Next.js for
GitHub Pages export and Vinext for Cloudflare output.
