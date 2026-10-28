# Changelog

## 3.3.0-dev — development preview, 2026-10-28

- Restored the full original-compatible Chrono runtime from pinned upstream revision `90be58b09fe420977afa691396238c7817c1766f`, preserving exact originals and attribution in `vendor/chrono`.
- Added wire-v2 bounded decoding, full source clocks, lifetime/ownership/teleport revisions, modular ordering and elapsed-time rate budgets.
- Added optional segment/linear drawing, bounded estimates, buffering/scheduling fixes and conservative culling.
- Added separate immutable graded history, independent source recording, authored pose/obstacle timelines, relative-motion contact and outcome/conflict helpers. These do not automatically validate arbitrary game movement or animations.
- Added the full-runtime setup plugin, 46 explained controls, private source backups, safe removal, startup readiness and F4 diagnostics. Existing Core 3.1 and Connector 3.2 sources remain unchanged.
- Integrated VERY EXPERIMENTAL prediction using existing packets, with 13 controls, separate estimate/drawing switches and no predicted hit records. Both switches default off. Engine rollback is separate and not certified by this work.
- Added matched original/fork single-client smoke results, synthetic transport and prediction replays, per-profile data, comparison examples and reproduction guides. Tested fingerprints and historical version labels are preserved.
- Kept the published 3.2 artifacts intact. The 3.3 preview is separate, with explicit unfinished release gates and no universal superiority claim.

## 3.2.0 — 2026-10-25

- Expanded Connector and its eight control tabs to expose existing Core timing, recording, data actor, query and obstacle capabilities. Core 3.1 source/math unchanged.
- Added Present / measured-ping / provider timing, explicit lookback limits and candidate-delivery requirements; removed the forced zero rewind.
- Added repeated active-window checks with whole-move duplicate/target limits, manual/event Capture and custom clocks, data-only actors/registries and recording-limit overrides.
- Added named body areas, visual multi-move profiles with offsets/rotation, static obstacle boxes and in-package historical-provider templates.
- Expanded generated calls, runtime policy reports, plain-language explanations and Studio guide. Added explicit source-checked runtime upgrades preserving customized Hooks/Actions.
- Passed 222 expanded runtime checks (160 randomized differential cases), 165 existing connection checks, 63 Core tests, 61 new editor checks and 39 existing editor checks: 550 total. These are integration checks, not new native network/performance benchmarks.

## Existing-game integration example — 2026-10-24

- Added a complete combat walkthrough: three plugin-generated calls in one existing script, with game-specific movement mapping inside supplied Hooks.
- Included the tested Hooks example, fixture-dependent test drivers and 80 final passing case results with source hashes and clear evidence limits.
- Kept original attack timing, overlap, damage, combo, blocking, animations and controls. Six original scripts stayed byte-identical; Core, Connector and supplied Movement were unchanged.
- Documented the bounded allowance for the game's existing knockback and finisher impulse. Final real movement flows recorded zero false refusals.
- Refreshed the website, downloads and manifest with both the connection workflow and this game-integration evidence. Earlier original-Chrono benchmarks retain their original labels.

## V3.1 connection workflow build — 2026-10-24

- Supplied server Connector: object discovery, shared recording, move references, cancellation, single-check outcome gating and Studio reports.
- Players, folder, tag and selected-reference object sources; server physics, a limited supplied humanoid checker, or an existing position provider.
- Existing BindableEvent links and in-package argument/provider mapping hooks. No gameplay RemoteEvent is added.
- Generated calls for existing server functions, reviewed insertions/teleport replacements and exact source-aware restore records.
- Connection settings updates preserve customized Hooks; removal refuses modified supplied source.
- Complete optional learning scene and Studio-only runtime guide. Core contact math and existing historical benchmark labels remain unchanged.

## 3.1.0 — 2026-10-21

- Six plain-language setup pages with examples, units, field links and a hitbox preview.
- Searchable explanations for 50 terms and 48 base result codes, including source/target-prefixed reasons.
- Optional `Core.Explain` and public type information for Studio suggestions.
- Generated practice module and disabled, Studio-only runner. Existing integrations stay untouched.
- Decimal comma or point input, clearer generated comments and updated in-game guides.
- 63 unit tests, 15 practice variants, 90 compiled generated files and 8,192 synthetic timeline regression scenarios passed in the recorded validation.
- Geometry, Shapes, History, Guard and Contract unchanged from the earlier numerical comparison build. No weaker contact acceptance policy.

## Repository presentation — 2026-10-22

- Published scope is ChronoFork V3.1 only, with portable source builds, Studio assets, a documentation website and explicit upstream/AI credits.
- Earlier measurements retain their original version labels. Historical branch code and the external legacy-world bridge are excluded.

This file covers the 3.3 development preview, stable 3.2 package and dated 3.1 changes. Earlier branch results remain comparison-only evidence.
