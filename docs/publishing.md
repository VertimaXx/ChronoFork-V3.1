# Repository and documentation publishing

Target repository: **VertimaXx/ChronoFork-V3.1**. The repository README is its GitHub homepage. The `site/` folder is a separate static documentation website, using no external scripts, fonts, analytics or build dependencies beyond Python.

## Build and check

```sh
python tools/build.py
python tools/check.py
```

Commit source and generated assets together. `dist/ChronoFork-3.1.0.zip` contains the V3.1 source, documents, Studio assets and recorded evidence; it contains no earlier branch implementation. `dist/MANIFEST.json` records hashes. Ignored optional upstream benchmark fixtures are never added to the package.

## GitHub Pages

In the repository's **Settings → Pages**, select **GitHub Actions** as the source. Then use **Actions → Publish documentation → Run workflow**. The included Pages workflow is manual so an ordinary code push does not silently deploy a website. The expected project-site address is:

`https://vertimaxx.github.io/ChronoFork-V3.1/`

The README link uses that address; it becomes live after a successful Pages deployment. See [GitHub's custom workflow guide](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) for the required permissions and environment. Configure a custom domain only if you own it and deliberately want one; no domain is assumed here.

## Optional tagged release

After reviewing the code and evidence labels, create tag `v3.1.0` and use the V3.1 section of CHANGELOG as the release summary. Attach the five `.rbxmx` models, ZIP and manifest from `dist/`. The README also links to committed downloads, so a release entry is optional. Do not describe old measurements as a fresh release benchmark.

## Repository description

Suggested description: **Unofficial, AI-assisted Chrono fork for checked server hitbox contacts in competitive Roblox games. V3.1 tools, guides, math and benchmark evidence.**

Suggested topics: `roblox`, `luau`, `hitbox`, `lag-compensation`, `competitive-games`, `chrono`, `roblox-studio`, `ai-assisted`.

Preserve the LICENSE, NOTICE and CREDITS. New maintainer contact information or a security-reporting policy should describe a channel that actually exists; none is invented by the package.
