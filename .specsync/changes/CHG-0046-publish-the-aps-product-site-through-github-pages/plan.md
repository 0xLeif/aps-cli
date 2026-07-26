---
change: CHG-0046-publish-the-aps-product-site-through-github-pages
artifact: plan
---

# Plan

1. Replace request-derived metadata with build-time site-origin metadata so the
   root route can be statically exported.
2. Add a conditional Next.js export configuration for GitHub Pages, including
   the `/aps-cli` base path and trailing-slash output.
3. Add a dedicated `build:pages` package script.
4. Add a GitHub Actions workflow that validates site changes on pull requests
   and deploys `site/out` after pushes to `main`.
5. Verify both the existing vinext build and the new static export.
6. Publish the changed existing site through Sites only if its built output
   changes.
