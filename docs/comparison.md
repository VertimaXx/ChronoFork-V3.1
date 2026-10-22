# Original Chrono and ChronoFork V3.1

**Choose by the job you need.** Original Chrono is a physics-replication library. ChronoFork V3.1 checks contacts using server-supplied gameplay records. They can be used in the same game, but combining them still requires checking what data your server can trust.

The upstream project describes its replication modes and `Chrono.Start()` setup in its [README](https://github.com/Parihsz/Chrono) and [documentation](https://parihsz.github.io/Chrono/). This fork's historical measurements use [one pinned revision](https://github.com/Parihsz/Chrono/tree/99e77a35822bca389f25a4d27d4de21249b287e0), not every version of Chrono.

## Different responsibilities

| Capability | Original Chrono | ChronoFork V3.1 |
|---|---|---|
| Custom transform replication | Included | Bring your existing system |
| Smooth remote-object presentation | Included | Bring your existing system |
| Earlier transform access | Snapshot API | Checked position, zones and state |
| Position interpolation in the comparison | Velocity-based Hermite | Linear position; shortest-arc orientation interpolation |
| Out-of-range behavior in the comparison | Endpoint returned | Query refused |
| Gameplay query shapes | Game builds its validator | Box, sphere, capsule, ray, swept sphere |
| Time gaps, age, resets and discrete boundaries | Game must establish its validation policy | Explicit checked-history policy |
| Automatic trusted movement / animated pose | Game-specific | Game-specific |
| Damage, tackles, possession, cooldowns | Game-specific | Game-specific |
| Installation for its basic purpose | Start replication | Import core or use guided setup; connect game boundaries |

“Not included” is a scope distinction. The benchmark does not count upstream's absent combat systems as failed tests.

## Matched history benchmark — earlier V3.0 run

Both implementations received **2,000 identical two-endpoint inputs** and **17 covered queries per case** (34,000 total). Endpoint positions span a scalar segment; endpoint velocities are randomized independently. The reference position is deliberately the straight line between endpoints.

| Metric | Original pinned Chrono | Fork checked history |
|---|---:|---:|
| Shared covered queries | 34,000 | 34,000 |
| Scalar endpoint-range overshoots | 5,958 | 0 |
| Mean distance from imposed straight line | 0.568265 studs | 0 in this test |
| Outside-range requests returning a pose | 4,000 / 4,000 | 0 / 4,000 |
| Outside-range requests refused | 0 / 4,000 | 4,000 / 4,000 |
| Mean query CPU time | 0.576888 µs | 1.540471 µs |

The fork used **about 2.67× the CPU time** in this microbenchmark. Its sample also checks age, gaps, record versions, a zone and scalar state. The original query returns a transform, so the contracts and work differ.

### What this shows

Linear position interpolation stays within its endpoint segment. Refusing an uncovered time gives a clearer evidence contract than silently returning a nearby endpoint. These are useful properties when a gameplay decision depends on what records exist.

### What this does not show

Random endpoint velocities can contradict the imposed straight line. A smooth nonlinear real trajectory can favor a different interpolator. Zero error against a deliberately linear reference is not zero real-world hitbox error. No universal hit-accuracy percentage, network improvement, whole-game FPS result, win-rate gain or anti-cheat certification follows.

These are **V3.0 measurements**, retained with their original labels. Geometry, Shapes, History, Guard and Contract were unchanged in V3.1; this is relevant continuity evidence, not a fresh timing run. [Raw earlier measurements](../benchmarks/data/v3.0-numerical.json) · [current V3.1 validation](../benchmarks/data/v3.1-validation.json) · [reproduction](benchmarks.md).

## Earlier competitive branches — comparison archive only

The following is historical **V2 versus original** evidence. It is not V3.1 performance, and neither V1 nor V2 executable code is included in this repository. V1's earlier experiments were superseded; no V1 result is used as evidence for V3.1.

| Historical paired replay metric | Original Chrono | Earlier V2 branch |
|---|---:|---:|
| Replay scenarios | 8,192 | 8,192 |
| Attempts per library | 374,798 | 374,798 |
| Covered attempts | 200,253 | 200,253 |
| Aim agreement on covered attempts | 98.6083% | 98.6512% |
| Mean error on covered attempts | 0.078284 studs | 0.078587 studs |
| Scalar overshoots | 1,092 | 0 |
| Off-segment observations | 37,139 | 0 |
| Reversal observations | 2 | 0 |
| Median kernel query time | 0.58275 µs | 0.64400 µs |

The agreement change was **0.04295 percentage points** in that workload, while mean covered error slightly increased and kernel CPU time increased about 10.5%. This is not an honest basis for saying “all hits are more accurate.”

The earlier V2 campaign also recorded 46,080 practical scenarios, 1,697,959 assertions and 156 contract checks. These involved a different controller/replication branch. A 144-attempt live endpoint-shim run recorded 123 hits, 7 world blocks, 2 expired commands and 12 rewind-limit refusals. An endpoint shim is not native transport testing. Those counts must not be added to V3.1's test count or presented as its coverage.

[Historical summary JSON](../benchmarks/data/historical-v2-summary.json) is preserved for traceability. This repository does not ship the old harness or promise one-command reproduction of that archived branch. New claims should use the current included harness and a separately recorded result.

## Practical choice

Use original Chrono when your immediate need is replication/presentation. Use this fork when you want explicit server contact checks and can supply checked positions, move authorization and outcomes. If those connections do not exist yet, the plugin can explain and scaffold them; it cannot infer your entire game's rules.
