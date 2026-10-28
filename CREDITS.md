# Credits and lineage

This repository additionally includes the **3.3.0-dev development preview**,
with original Chrono's complete runtime restored from commit
`90be58b09fe420977afa691396238c7817c1766f`. Exact originals and their MIT notice are
in `vendor/chrono`; modified runtime sources are in `replication`. The upstream
Signal implementation's embedded stravant attribution is retained. This work was
implemented and tested with OpenAI Codex / AI under VertimaXx's direction. It is
not an upstream release, endorsement or independent security audit. See the
[preview guide](docs/full/start-here.md) and [current validation](docs/full/validation.md).

**ChronoFork V3.2 is an unofficial Chrono fork, developed with AI assistance.** The Connector/plugin is 3.2.0 and uses unchanged Core 3.1.0. The repository URL keeps its original ChronoFork-V3.1 name.

| Contributor | Credit |
|---|---|
| [Parihsz](https://github.com/Parihsz) and [original Chrono contributors](https://github.com/Parihsz/Chrono/graphs/contributors) | Original Chrono physics-replication project, design and upstream foundation. Original MIT copyright is retained. |
| **OpenAI Codex / AI** | AI-assisted competitive-branch implementation, mathematical analysis, integration tools, explanatory GUI, tests, comparisons and documentation. AI assistance is explicit; it is not an independent audit or certification. |
| [VertimaXx](https://github.com/VertimaXx) | Project direction, competitive requirements, feedback and repository ownership. |
| Roblox / Luau contributors | Engine, Studio, language and APIs used by the project. These tools' ownership is not claimed by this fork. |

## What “fork” means here

The competitive work began by studying and extending Parihsz/Chrono. Earlier experimental branches included replication and movement work. The current V3.2 package is the standalone contact-validation branch of that lineage, carrying forward unchanged Core 3.1 geometry/history/guard work. It does **not** contain the entire original replication framework, and its API differs from upstream.

“V3.2” names this independent branch's current package. It does not mean that Parihsz published Chrono 3.2 or endorses this repository. It is not a claim about GitHub's fork-network metadata. Historical V1/V2 code is not shipped here; a labeled comparison appendix preserves selected earlier results.

The matched original-code benchmark used upstream revision:

`99e77a35822bca389f25a4d27d4de21249b287e0`

See [the pinned source](https://github.com/Parihsz/Chrono/tree/99e77a35822bca389f25a4d27d4de21249b287e0), [benchmark provenance](docs/benchmarks.md) and the preserved [MIT license](LICENSE). Future upstream changes are not represented by that historical benchmark.

No new ownership claim is made on behalf of OpenAI, Roblox or upstream contributors. Attribution is distinct from copyright ownership. Please preserve the MIT notice and this origin explanation when redistributing the fork.
