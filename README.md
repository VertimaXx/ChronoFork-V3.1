<p align="center"><img src="site/assets/banner.svg?v=3.2-style" alt="ChronoFork V3.2 — checked contacts for competitive Roblox games" width="100%"></p>

<p align="center"><img src="site/assets/project-badges.svg" alt="Version 3.2.0 · Roblox / Luau · MIT license · AI-assisted development" width="600"></p>

<p align="center"><strong>Your movement. Your moves. Checked contact evidence.</strong><br>
<a href="https://vertimaxx.github.io/ChronoFork-V3.1/">Documentation website</a> · <a href="docs/start-here.md">Start here</a> · <a href="docs/comparison.md">Original vs fork</a> · <a href="docs/benchmarks.md">Benchmarks</a> · <a href="CREDITS.md">Credits</a></p>

# ChronoFork V3.2

**Connector/plugin 3.2.0 expands the plugin to the existing Core's full connection capabilities. Core stays at 3.1.0 with unchanged source and math.** Configure earlier timing, repeated checks, recording/clocks, pure-data actors, per-object limits, named body areas, multiple move profiles and obstacles through the [complete controls guide](docs/connector-controls.md). Existing releases and comparison results keep their original labels.

**Check whether a move's hitbox touched an allowed object, using positions your server calculates or checks.** Built for game-owned tackles, ball contacts, melee moves, rays and swept spheres. Your game decides what the contact means: possession, damage, stun, a block or something else.

**This is an unofficial Chrono fork. Original credit belongs to [Parihsz and the Chrono contributors](https://github.com/Parihsz/Chrono). The competitive branch, tools, tests and documentation were developed with OpenAI Codex / AI, under VertimaXx's direction.** The upstream MIT notice is preserved. See [credits and lineage](CREDITS.md).

V3.2 is a standalone contact-validation branch of that work, using unchanged Core 3.1. It does not bundle original Chrono's physics-replication framework and does not replace `Chrono.Start()`. You can keep an existing replication system and supply checked server data through the plugin's connection package.

## What you get

- **Five query shapes:** box, sphere, capsule, ray and swept sphere. Target hitboxes can be boxes, spheres or capsules.
- **Checked earlier positions:** refuses missing, too-old or uncertain records instead of silently substituting an endpoint. A reset separates data before and after a teleport or respawn.
- **Game-owned connections:** movement, animations, VFX, cutscenes, camera and outcomes remain in your game.
- **Studio connection workflow:** six setup pages and eight connection tabs for objects, named body areas, multiple moves, timing, recording, events, generated calls and testing/restoration.
- **Selectable timing and checking:** present or explicitly approved earlier positions; Once or Repeated checks; automatic, manual or event-controlled recording.
- **Flexible object and obstacle sources:** Parts or pure server data, per-kind/object recording limits, anchored obstacle boxes and in-package provider templates for custom systems.
- **Position-source choices:** server-owned physics, a supplied limited humanoid checker, or your existing checker with mapping functions inside the package.
- **Beginner-friendly help:** 50 explained terms, 48 Core result messages, additional Connector explanations, examples and optional in-game developer guides. Decimal comma and decimal point inputs are supported.
- **Practice before integration:** a test using made-up server values starts disabled. It helps you learn; it does not certify your game.

![V3.1 setup and hitbox preview in Roblox Studio](site/assets/hitbox-3.1.jpg)

*Real V3.1 setup view from the development lab. The background arena is not shipped with this repository.*

## Install from scratch

1. Download [ChronoV3Setup.rbxmx](dist/ChronoV3Setup.rbxmx) using GitHub's **Download raw file** button, or download the [complete V3.2 bundle](dist/ChronoFork-3.2.0.zip) and extract it.
2. In Studio's Explorer, right-click **ServerStorage → Insert from File** and select the setup file. Right-click the inserted **ChronoV3Setup** Script → **Save as Local Plugin**. Save it as **Chrono V3**, then remove the imported source Script from your place.
3. Use **Plugins → Chrono V3 → ChronoSetup**. Complete the setup, review the generated code, then add it. **This is the plugin integration step.**
4. On **Connect your game**, select objects and a position source, add the supplied connection package, then link existing server events or use **Calls** to generate and insert the small calls your game needs. Customize supplied Hooks for unusual rules.
5. Press Play and inspect the connection guide/report. Test the actual game with multiple clients and Studio's Network Simulator. For a first success with no scripting, **Try a complete supplied learning scene** on page 1.

The [connection walkthrough](docs/connections.md) explains the current workflow; [full controls](docs/connector-controls.md) covers every connection tab and upgrades. [Start here](docs/start-here.md) also documents the advanced low-level API. Prefer code-only installation? Import [ChronoV3.rbxmx](dist/ChronoV3.rbxmx) as a ModuleScript, or map `src/` with the included [Rojo project](default.project.json).

| Download | Purpose |
|---|---|
| [Setup plugin](dist/ChronoV3Setup.rbxmx) | Guided setup and source generator |
| [Core module](dist/ChronoV3.rbxmx) | Library without the plugin |
| [Toolkit](dist/ChronoV3Toolkit.rbxmx) | Core 3.1, setup/Connector 3.2 and developer examples together |
| [Developer guide](dist/ChronoV3Guides.rbxmx) | Optional in-game instructions; restrict access to your developers |
| [Tests](dist/ChronoV3Tests.rbxmx) | Import into a separate Studio place |
| [Complete ZIP](dist/ChronoFork-3.2.0.zip) | Source, assets, documentation and recorded results |

The toolbar and ModuleScript names remain `Chrono V3` / `ChronoV3` for compatibility. Connector/plugin version is **3.2.0**; Core remains **3.1.0**. The repository URL retains its original name.

## How your game connects

```text
Your server's checked positions → Track + Capture → short position record
Your server accepts a move      → BeginAction     → Query during hit period
Covered contacts               → your current rules → apply a result once
Move ends or is cancelled      → EndAction
```

**Server decides** means the server calculates a value or checks that it was allowed. Developers often call this *authoritative*. Reading a client-controlled part on the server does not establish that its movement was allowed.

The supplied **Connector** handles object tracking, recording, move references, checks and cancellation. Choose automatic recording or connect your simulation's Capture call/event. Select existing events or insert generated calls at accepted-move and outcome points. Unusual mappings belong in supplied Hooks/provider files. No gameplay remote is added. See [the connection walkthrough](docs/connections.md) or [the exact API](docs/integration.md).

**A tested existing-game example:** one melee game's connection required three plugin-generated call blocks in one original script. Its movement rules were mapped inside supplied Hooks; six other original scripts stayed byte-identical. All 80 recorded integration checks passed. This was active contact rejection, with rewind off. [Follow the exact developer steps and inspect the evidence](docs/combat-walkthrough.md).

## Compared with original Chrono

| Question | Original Chrono | ChronoFork V3.2 |
|---|---|---|
| Main job | Physics replication and smooth presentation | Checked gameplay contact evidence |
| Basic setup | `Chrono.Start()` for replication | Plugin or module, then explicit game connections |
| Earlier-time result | Transform snapshot API; caller must check evidence policy | Strict coverage, age, gap, reset and state checks |
| Character movement / animation validation | Game-specific work | Still game-specific work |
| Complete anti-cheat / finished combat system | No | No |

In the **earlier V3.0 matched history benchmark**, 34,000 covered queries used the same two endpoints and randomized endpoint velocities. Original Chrono overshot the scalar endpoint range 5,958 times; the fork's linear positions did so zero times. The test deliberately imposed a straight-line reference that the velocities could contradict. This demonstrates interpolation behavior, **not a universal hit-registration accuracy improvement**.

Checked query time in that run averaged **1.540 µs vs 0.577 µs** for original Chrono, about **2.67× the CPU time**. The fork also interpolated a zone and checked state; original returned a transform. No FPS or bandwidth advantage is claimed. [Read the methods, tradeoffs and full comparison](docs/comparison.md).

## Recorded validation

| Evidence | Result | When / meaning |
|---|---:|---|
| Current 3.2 integration/regression checks, 25 Oct | **550 / 550 passed** | 222 expanded runtime, 165 existing connection, 63 Core, 61 expanded editor and 39 existing editor checks |
| Included randomized Core comparisons | 160 / 160 passed | Part of the 222 runtime checks; wiring parity across shapes, rotations, positions and lookback policies |
| V3.1 unit tests | 63 / 63 passed | Includes randomized math groups; not 63 independent game trials |
| V3.1 timeline scenarios | 8,192 / 8,192 passed | Seeded synthetic timing; RTT policy inputs 0–1,000 ms |
| V3.1 practice variants | 15 / 15 passed | Three presets × five query shapes |
| V3.1 generated source | 90 files compiled | Six generated files per variant |
| V3.1 real installer checks | 8 / 8 passed | Including Undo, Redo, rollback and conflict preservation |
| V3.1 connection workflow, 24 Oct | 39 edit + 165 runtime + 63 core checks passed | Supplied connections, generated calls, real client and learning scene |
| V3.1 existing combat integration, 24 Oct | 80 / 80 passed; 27 installed sources compiled | 59 baseline comparisons, 8 client inputs, 9 gate checks, 4 movement flows; one client, zero added delay |
| Earlier V3.0 engine geometry oracle | 6,000 / 6,000 passed | Roblox overlap/cast comparisons; sweep tolerance 0.025 studs |
| Earlier V3.0 matched history | 34,000 shared covered queries | Pinned original source and deliberately linear reference |

All Core source remains unchanged in 3.2. **Earlier timing and engine-oracle results remain earlier measurements.** The 550 current checks used one Studio workstation/client and deterministic server scenarios. They add no new native-network or CPU/FPS benchmark, and do not certify a competitive game. [Raw JSON, workload details and reproduction](docs/benchmarks.md).

## Know the limits before choosing it

Use positions the server calculates or genuinely checks. The supplied humanoid option adds bounded root checks for ordinary static-ground movement; it does not solve all movement security. Your game still validates input, cooldowns, stamina and ownership and owns its outcomes. Connector supports Once or Repeated checks, with whole-move target limits. Sampled hitboxes do not reconstruct every path between updates. Exact animated limbs and moving historical obstacles need game-specific providers. Strict uncertainty can refuse an action; joins/removals invalidate active actions globally. Matching actors and zones are scanned, so profile real workloads.

Read the [ranked limitations and math](docs/math-and-limits.md). A successful query with zero contacts is a checked miss. A refused query means evidence was insufficient; it is a separate result.

## Documentation

- [Start here](docs/start-here.md) — installation and first success
- [Plugin connections](docs/connections.md) — first connection, events/calls, testing and restore
- [All connection controls](docs/connector-controls.md) — timing, repeated checks, recording, clocks, data actors, bodies, moves, obstacles and upgrades
- [Existing combat walkthrough](docs/combat-walkthrough.md) — exact plugin steps, three generated calls and in-package movement mapping
- [Connect your game](docs/game-integration.md) — sports, melee and ray examples; responsibilities
- [Exact API](docs/integration.md) — functions, values and bounds
- [Math and limitations](docs/math-and-limits.md) — calculations and ranked tradeoffs
- [Comparisons](docs/comparison.md) — original Chrono and historical comparison-only appendix
- [Benchmarks](docs/benchmarks.md) — methods, raw results and reproduction
- [FAQ](docs/faq.md) · [Credits](CREDITS.md) · [Contributing](CONTRIBUTING.md)

## Build from source

Python 3.10+ is enough to rebuild the assets, website and ZIP. No external Python packages are required.

```sh
python tools/build.py
python tools/check.py
```

These commands check packaging and documentation, not Roblox runtime behavior. The Studio tests and optional Luau compilation are described in [benchmarks](docs/benchmarks.md). This repository ships **V3.2 Connector/plugin with unchanged V3.1 Core**. Earlier V1/V2 work appears solely as historical comparison evidence.

MIT licensed. Original copyright retained. [Parihsz/Chrono](https://github.com/Parihsz/Chrono) is the upstream project; this fork is independently maintained and is not an official upstream release.
