# Repository and documentation publishing

Target repository: **VertimaXx/ChronoFork-V3.1**. The repository README is its GitHub homepage. The `site/` folder is a separate static documentation website, using no external scripts, fonts, analytics or build dependencies beyond Python.

## Build and check

```sh
python tools/build.py
python tools/check.py
```

Commit source and generated assets together. `dist/ChronoFork-3.2.0.zip` contains Connector/plugin 3.2, unchanged Core 3.1, documents, Studio assets and recorded evidence. It contains no earlier branch implementation. `dist/MANIFEST.json` records hashes. Ignored optional upstream benchmark fixtures are never added to the package. Do not overwrite an already-published release's versioned assets; use a new release for new builds.

## GitHub Pages

In the repository's **Settings → Pages**, select **GitHub Actions** as the source. Then use **Actions → Publish documentation → Run workflow**. The included Pages workflow is manual so an ordinary code push does not silently deploy a website. The expected project-site address is:

`https://vertimaxx.github.io/ChronoFork-V3.1/`

The README link uses that address; it becomes live after a successful Pages deployment. See [GitHub's custom workflow guide](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) for the required permissions and environment. Configure a custom domain only if you own it and deliberately want one; no domain is assumed here.

## Tagged release

Create tag `v3.2.0` at the final published source commit and use the 3.2 section of CHANGELOG as the release summary. Attach five `.rbxmx` models, ChronoFork-3.2.0.zip, MANIFEST.json and SHA256SUMS.txt from `dist/`. Keep v3.1.0 unchanged. The README also links to committed downloads. Describe 550 current integration checks separately from older original-Chrono performance measurements.

## Repository description

Suggested description: **Unofficial, AI-assisted Chrono fork for competitive Roblox contact checks. V3.2 plugin/Connector, unchanged Core 3.1, guides and inspectable validation.**

Suggested topics: `roblox`, `luau`, `hitbox`, `lag-compensation`, `competitive-games`, `chrono`, `roblox-studio`, `ai-assisted`.

Preserve the LICENSE, NOTICE and CREDITS. New maintainer contact information or a security-reporting policy should describe a channel that actually exists; none is invented by the package.
