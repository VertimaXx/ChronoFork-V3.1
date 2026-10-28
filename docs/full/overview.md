# ChronoFork 3.3 development preview

**Experimental development work, dated 28 October 2026. Stable release: 3.2.0.**
This is an unofficial fork of Parihsz/Chrono, implemented with OpenAI Codex / AI
under VertimaXx's direction. Original copyright and contributor credits remain.

The 3.2 release supplies competitive contact checks and a connection plugin.
The 3.3 preview adds original-compatible movement replication alongside those
checks. It also adds separate evidence helpers and very experimental prediction.
It is not a claim that every part is faster, more accurate or ready for production.

## What changed since 3.2

| Area | 3.3 preview addition | Practical limit |
|---|---|---|
| Original Chrono runtime | Complete pinned upstream runtime with original API paths, ownership, player lifecycle, mounting and three model modes | Public API compatibility does not mean mixed-version network compatibility |
| Packet handling | Bounded whole-packet decoding, full source clocks, lifetime/revision/sequence checks and elapsed-time budgets | Input bounds do not prove safe movement |
| Drawing | Segment/linear/original curves, improved scheduling and buffering, conservative culling | Smooth or predicted positions are not hit evidence |
| Recorded evidence | Separate immutable, graded records and independently captured sources | Your game must supply trustworthy state |
| Motion/contact helpers | Relative sphere continuous contact, bounded volume refinement, authored pose timelines and historical world providers | Complex or unresolved motion can return unknown; game-specific connections remain |
| Outcome helpers | Duplicate/conflict handling for results, possession and rounds | Not an automatic game-rule or transaction system |
| Engine simulation adapter | Shared simulation and deferred-effect hooks | Requires your shared controller and real rollback testing |
| Full-runtime setup | 46 explained controls, source-aware installation/removal, private backups and F4 diagnostics | Advanced contact helpers are not all automatically wired into the contact wizard |
| Prediction experiment | Separate server/client estimates, 13 controls, optional remote drawing | VERY EXPERIMENTAL, off by default; no predicted hit records |

Core 3.1 and the published Connector 3.2 remain unchanged. Choose a full-runtime
setup only if you want Chrono to drive replication; do not run two movement drivers
on the same objects.

## Choose your download

The stable 3.2 files and their recorded results remain in `dist/`. The preview
files are separate in `dist-preview/`:

- [3.3 setup plugin](../../dist-preview/ChronoForkSetup.rbxmx): movement setup plus the existing contact wizard.
- [3.3 runtime](../../dist-preview/ChronoFork.rbxmx): library without the editor plugin.
- [3.3 Studio tests](../../dist-preview/ChronoForkTests.rbxmx): disposable validation fixture.
- [3.3 complete bundle](../../dist-preview/ChronoFork-3.3.0-dev.zip): source, models, guides and evidence.
- [File hashes](../../dist-preview/MANIFEST.json) and [download checksums](../../dist-preview/SHA256SUMS.txt).

Follow the [installation guide](start-here.md). Use **ChronoSetup → Experimental**
only when deliberately testing prediction. Its main switch and drawing switch
both start off. [Prediction controls and math](prediction.md) explain what those
estimates can and cannot establish.

## What has been tested

7,121 seeded/property/regression cases and a separate 864-profile synthetic
transport campaign were recorded. The earlier matched native fixture completed
eight original/fork single-client runs across four impairment profiles. The
prediction model was checked over two seeds, 2,160 synthetic profiles and 682,560
positions. Its integration has separate service/lifecycle, 46-control setup and
enabled/disabled native smoke checks.

These categories are different kinds of evidence, not thousands of real matches.
The current preview contains later changes than the first native benchmark build;
raw records preserve their tested build fingerprints.

In the prediction replay, mean error improved about 49% over the old 100 ms
estimate but only 2.80% over straight prediction with the same larger limits.
Some tail results regress. The native runtime fixture used roughly twice the
original's raw state-buffer bytes; total wire traffic was not measured. No
universal accuracy, latency, bandwidth, CPU or fairness advantage is established.

Read [validation and costs](validation.md), [prediction results](prediction-results.md),
[math and limitations](math-and-limits.md), and [remaining release gates](../../IMPLEMENTATION.md).
The [reproduction guide](reproduce.md) separates synthetic tests from native runs.

## Help test it

Back up a small test place and connect one representative move. Try multiple
clients, both good and poor connections, sudden stops/turns, teleports, ownership
changes, respawns, walls and moving objects. Report the version, settings, expected
result, actual result and a minimal reproducible example. Do not include private
player data or treat a perfectly aligned local rectangle as proof of server accuracy.

Use [GitHub issues](https://github.com/VertimaXx/ChronoFork-V3.1/issues) for feedback.
