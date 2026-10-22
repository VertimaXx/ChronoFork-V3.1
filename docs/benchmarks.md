# Benchmarks, methods and reproduction

**Counts below describe recorded evidence, not a promise that every competitive situation has been tested.** Results come from one Roblox Studio workstation. Engine/build and hardware details were not fully recorded in the earlier run, so absolute timings are local observations. Do not treat them as a hardware-independent ranking.

## Evidence register

| Artifact | Version / date | What it establishes |
|---|---|---|
| [Current validation JSON](../benchmarks/data/v3.1-validation.json) | 3.1.0 / 2026-10-21 | Unit, generated practice, timeline regression, installer and Studio GUI results |
| [Earlier numerical JSON](../benchmarks/data/v3.0-numerical.json) | 3.0.0 / 2026-10-21 | Original-code comparison, engine geometry oracle and full-service load measurements |
| [Historical V2 summary](../benchmarks/data/historical-v2-summary.json) | competitive.2 / 2026-10-20 | Archived comparison-only evidence for a different earlier branch |
| [Package manifest](../dist/MANIFEST.json) | 3.1.0 packaging / 2026-10-22 | SHA-256 for source, assets and documents shipped here |

The recorded V3.1 evidence says Geometry, Shapes, History, Guard and Contract were unchanged from the earlier V3.0 build. New packaging removes a legacy UI hint and an external legacy-world example; core acceptance logic is preserved. This does not relabel earlier performance runs as current runs. The build checks verify that model assets contain the repository's source.

## Current V3.1 validation

- **63 / 63 unit tests.** Tests include contract failures, histories, geometry, action lifetime, duplicate handling, editor validation and readable help. Three mathematical groups internally exercise 4,000 interval cases, 3,600 rotated symmetry/invariance cases and 2,500 swept-capsule scalar-distance cases. Those nested cases are not extra independent unit-test rows.
- **8,192 / 8,192 timeline scenarios**, with 12,718 assertions and seed 20261021. These are deterministic server-timeline simulations, not packets crossing a native network.
- **15 / 15 generated practices**, covering three presets and five shapes. An ordinary server Script also ran a generated practice successfully.
- **90 generated Luau files compiled**, six files for each practice variant.
- **Eight real installer checks:** install, practice initially disabled, game not certified, practice module present, Undo, Redo, rollback and preserving existing code.
- **Studio UI:** six pages exercised; 360×480 and 500×780 layouts checked with zero measured label overflow; actual Next click and decimal-comma input passed. Shape previews and in-game guides were visually reviewed. This is not a formal accessibility or translation audit.

### Timeline coverage

Synthetic RTT policy inputs are 0, 16, 33, 50, 80, 100, 150, 200, 300, 500, 750 and 1,000 ms, with independent randomized rewind jitter. These inputs choose a delay policy; they do not measure transport latency or prove a one-way estimator.

The scenario groups cover clean data, jitter, server hitches, state transitions, teleports, provider faults, unverified actors, cover, roster changes, duplicate queries, expired actions, reversed clocks, resized hitboxes and cancellation. Query shapes are box/sphere/capsule/sweep, and target zones box/sphere/capsule. Practice and unit coverage separately exercise rays. All labels and individual shape counts are in the raw JSON.

Expected coverage is derived separately from scalar capture times and state transitions. This is useful policy testing, but the generator explores its authored model, not all possible game/network behavior. Counts cannot certify a particular game's animation, controller or outcome code.

## Earlier engine geometry oracle

6,000 cases passed: 2,000 rotated box/box overlaps, 2,000 sphere/box overlaps and 2,000 sphere/box casts against Roblox's engine. Seed: 471021. Cast-distance disagreement tolerance: **0.025 studs**. Engine tolerances and mathematical primitive tolerances differ.

This oracle does not cover every shape pair, arbitrary meshes, terrain, every scale, continuous relative motion or every numerical singularity. Independent randomized math groups complement it but are not a proof of exact arithmetic.

## Earlier matched original-code benchmark

Upstream pin: `99e77a35822bca389f25a4d27d4de21249b287e0` from [Parihsz/Chrono](https://github.com/Parihsz/Chrono/tree/99e77a35822bca389f25a4d27d4de21249b287e0).

The [included harness](../tests/MatchedBenchmark.luau) uses seed **8841021**, 2,000 endpoint/velocity cases, 17 covered queries per case and two outside-range queries per case. Both receive the same endpoint transforms and timestamps; original Chrono also receives the randomized velocities. The reference is deliberately the linear path. Contradictory endpoint velocities stress overshoot rather than model a guaranteed physical trajectory.

Original mean query CPU: **0.576888 µs**. Fork checked-history mean: **1.540471 µs**. Scalar overshoots: **5,958 versus 0**. Mean distance to the imposed line: **0.568265 versus 0 studs**. All 4,000 uncovered original requests returned an endpoint; the fork rejected all 4,000. See the [comparison and interpretation](comparison.md).

The harness measures accumulated `os.clock()` time around individual calls in one engine session. Original runs before the fork in each pair; no randomized order, cross-machine confidence interval or production-server distribution was recorded. Per-call clock overhead and cache/order effects matter at microsecond scale. Return contracts differ. This benchmark is not an end-to-end hit decision, packet bandwidth or FPS test.

The original pinned source used `const`. The historical engine-compatible fixture normalized those declarations to `local`; arithmetic was not intentionally changed. The optional fetch tool below preserves original bytes/hashes, performs token-aware compatibility normalization, and records both hashes. It does not vendor the original framework into the game library.

## Earlier full-service CPU workload

The [load harness](../tests/LoadBenchmark.luau) measures BeginAction + Query + EndAction, one sphere per actor, no contacts and no world provider. Each roster size uses five batches of 250 iterations. Numbers are the **median/min/max of batch means**, not per-query p50/p95/p99.

| Actors | Median batch mean | Min–max batch mean |
|---|---:|---:|
| 16 | 21.38 µs | 17.94–26.73 µs |
| 32 | 33.85 µs | 26.53–37.95 µs |
| 64 | 50.73 µs | 41.59–53.05 µs |
| 128 | 82.01 µs | 77.39–85.68 µs |
| 256 | 149.88 µs | 142.03–162.76 µs |

Capture cost, multi-zone actors, game callbacks, world history and actual network activity are excluded. The current service scans matching actors/zones. No original full-service equivalent is presented because original Chrono does not implement the same service. Profile your actual roster, move rate and zone count.

## Reproduce the included tests in Studio

Use a **separate empty test place**, save it first, and keep your production place untouched. Rebuild assets with `python tools/build.py`, or use the committed files. Import `ChronoV3Tests.rbxmx` into **ServerStorage**; it creates `ChronoV3Validation` and `UnitTest` folders. Keep these names because the tests use them. The model is inert: it contains test ModuleScripts, not an automatic runner.

Add a server Script under **ServerScriptService**, paste the following, then start Play. Read Output and stop Play afterward.

```luau
local Http = game:GetService("HttpService")
local storage = game:GetService("ServerStorage")
local validation = storage:WaitForChild("ChronoV3Validation")
local report = {
    version = require(validation.Core).Version,
    unit = require(storage.UnitTest.RunUnitTest)(),
    timeline = require(validation.Campaign)(8192),
    oracle = require(validation.EngineOracle)(validation.Core, 6000),
}
assert(report.unit.failed == 0, "Unit failures; read Output")
assert(report.timeline.passed == report.timeline.scenarios, "Timeline failures")
assert(report.oracle.passed == report.oracle.cases, "Engine oracle failures")
print(Http:JSONEncode(report))
```

Save your output with source manifest, Studio build, hardware, sample count, seed and relevant settings. A new run is new evidence; do not overwrite the archived JSON. GUI installation/Undo, generated practices, compiler checks and native network sessions are separate activities; the runner above does not reproduce those automatically.

For the load workload, add this inside the same server Script after validation and print its result. Run in an otherwise quiet session and repeat with a documented warm-up/order policy if comparing timings.

```luau
local load = require(validation.LoadBenchmark)(validation.Core)
print(Http:JSONEncode({load = load}))
```

### Prepare the original baseline

On your computer, run:

```sh
python tools/fetch_baseline.py
```

The optional tool downloads only the five pinned upstream modules needed for this microbenchmark, preserves the upstream MIT license and original bytes, and writes provenance hashes under ignored `vendor/upstream-baseline/`. It performs no install or publication. Import the generated `OriginalChronoBaseline.rbxmx` into ServerStorage in the test place, then add:

```luau
local matched = require(validation.MatchedBenchmark)(
    validation.Core,
    storage.OriginalChronoBaseline
)
print(Http:JSONEncode({matched = matched}))
```

This fixture is for the benchmark only. Do not use it as a complete original-Chrono installation. The fetch and matched methods are inspectable; earlier raw results remain the original recorded run, even if a fresh engine produces different values.

### Plugin and real-game tests

Use the setup plugin in a saved test place to exercise install, destination conflict, Undo/Redo, a disabled practice runner and your generated practice. Source for installer cases and the earlier ordinary-script adapter smoke is in `tests/`; the smoke expects a generated `ServerScriptService.ChronoV3SmokeIntegration` configured for the sports example and is not run automatically.

Use Studio's [Network Simulator](https://create.roblox.com/docs/studio/network-simulator) with multiple clients for actual native transport. Establish a zero-added-delay baseline by checking all six directional settings. Then vary inbound/outbound latency independently, jitter and loss. Record seeds/settings, server scheduling, refused reasons, contact/outcome agreement and frame costs. Exercise packet bursts/reordering, long stalls and recovery through the actual game's channels. **No V3.1 native transport run is claimed by the archived JSON.**

## Rebuild and inspect packaging

`python tools/build.py` rebuilds models, the static website, the manifest and ZIP from this repository. `python tools/check.py` checks hashes, embedded-source parity, local documentation/site links and archive integrity. Add `--luau-compile /absolute/path/to/luau-compile` for syntax compilation if the official Luau CLI is installed. Roblox APIs require Studio; standalone Luau cannot execute the runtime suite as-is.

Packaging CI does not rerun Studio, the geometry engine, native networking or real game integration. A green workflow is a packaging check, not a gameplay certification.

## Known evidence gaps

No independent external audit, production competitive-game integration, representative server fleet, full native-network campaign, arbitrary trusted animation pipeline, all-shape engine oracle or exhaustive numerical proof has been completed. The historical HTML guide lacked browser visual verification. The new website's own publishing checks are separate from the preserved software-validation files. Be precise when reusing any figure.
