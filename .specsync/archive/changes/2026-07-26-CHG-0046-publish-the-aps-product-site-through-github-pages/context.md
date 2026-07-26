---
change: CHG-0046-publish-the-aps-product-site-through-github-pages
artifact: context
---

# Context

The aps product site source lives under `site/`, while GitHub Pages branch
publishing only accepts the repository root or `docs/`. Moving generated site
files into `docs/` would mix authored documentation with build output and make
the vinext source harder to maintain.

GitHub Pages supports custom Actions workflows that upload an arbitrary static
artifact. The existing site can therefore remain under `site/` if it gains a
static export mode for the `/aps-cli` project path.

The current OpenAI Sites deployment remains a valid production target. GitHub
Pages is an additional public delivery path and must not break the existing
Cloudflare-compatible vinext build.
