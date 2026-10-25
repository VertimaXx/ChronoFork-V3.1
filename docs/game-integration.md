# Connect the game you already have

For Connector/plugin 3.2 with unchanged Core 3.1, start with [Plugin connections](connections.md) and [all controls](connector-controls.md). The plugin supplies tracking, recording and move bookkeeping, including earlier timing, repeated checks, data actors and custom providers. The rest of this page explains game responsibilities and the advanced API.

You do not need to rewrite every animation, effect or cutscene. Connect the places where your **server** records positions, accepts moves and applies their results. Names such as ActorService in the example are your own code, not Roblox services supplied by this package.

## Four connections

| Connection | Plain meaning | What you supply |
|---|---|---|
| Object data | Where each object and hitbox is at an update | A function returning `root`, `zones`, and small game values in `state` |
| Update boundary | All participating objects finished the same simulation step | Call `Capture` after that common step; capture once before accepting moves |
| Move boundary | Your server accepted a move request | Call `BeginAction`, `Query` during its hit period, and `EndAction` on completion/cancellation |
| Outcome boundary | Decide what a returned contact does now | Recheck current rules and apply possession, stun, damage or another effect once |

An object-data function is often called a **provider**. A **snapshot** is one saved record. **History** is the short collection of earlier records. These are ordinary Luau functions and tables; learn the four connections first, then look up precise values as needed.

## Examples across competitive genres

| Game situation | Possible query | Game-owned decision |
|---|---|---|
| Football tackle | Root-relative box or capsule during an accepted tackle | Opposing team, ball possession, immunity, foul rules and stun |
| Ball interception | Sphere or swept sphere | Valid ball state, catch window, possession transfer and tie-breaking |
| Melee strike | Deliberate gameplay box/capsule or several approved sweep samples | Combo, cooldown, parry state, damage and cancellation |
| Hitscan move | Ray or positive-radius sweep | Aim authorization, ammo, historical cover and damage |
| Cutscene finisher | Usually pause/cancel normal moves explicitly | Cutscene eligibility, resets, invulnerability and animation orchestration |

These are starting shapes, not automatic exact animation reconstruction. A curved foot path or moving sword needs a deliberate trusted pose/sweep policy. A spatial sweep holds the target fixed at the sampled time; it is not full continuous collision between both moving actors.

## Use the generated files

The usual workflow uses Connector, ConnectionData and Hooks. Use the Bodies/Moves tabs for visual configuration, and provider templates for custom data, clocks, timing or obstacles. The Bindings/low-level constructor below is an alternative; do not start it alongside Connector.

- `Bindings`: connect your object and update functions. A selected Studio reference starts unverified.
- `Actions`: choose shape, target kinds, hit period and rules using saved state.
- `Settings`: choose record age, sample-gap tolerance and optional approved rewind.
- `Practice`: complete made-up example for learning.
- `RunPractice`: starts off; Studio-only test runner. Turn it off after practice.
- `Core`: the library. `Core.Explain(result)` gives a readable explanation of a refusal.

[SportsAdapter.luau](../examples/SportsAdapter.luau) shows how an existing move/actor/ball service could connect. Replace its service calls with your own. It does not create those services. The plugin writes a **new** namespace and preserves existing work; updates are reviewed manually.

## Where trust comes from

`serverSimulated` means your server calculated the positions. `serverValidated` means your server independently checked the proposed movement against your game rules. These are declarations about your provider. Merely choosing either label, receiving a RemoteEvent or reading a replicated part does not perform that validation.

Authenticate move requests and reject replay before creating a handle. Check stamina, cooldown, range, team, possession, cancellation and round state in your game. A returned contact is evidence for that query; it is not permission to blindly apply any effect. The library suppresses repeat targets per handle, but your outcome code must also avoid applying one result twice.

## Resets and changes

Call `Discontinuity` after an approved teleport, respawn or physics-owner change. This begins a new position-record version, called an **epoch**. Earlier and later records must not be joined. A provider fault pauses that actor's evidence until you fix it and explicitly reset. Do not reset repeatedly to hide a data fault.

Use `Untrack` when an actor leaves. Current policy invalidates active moves globally when the roster changes. Decide whether your game should authorize a new move; do not silently bypass a refusal.

## Obstacles, timing and animation

Obstacle checking is optional. With `world=false`, the query checks contacts without map obstruction. If your game disallows a tackle through a wall, add that rule explicitly. The optional historical-world callback supports rays and swept spheres; it must establish geometry at the historical time and initial overlap, not just raycast today's map.

Earlier-time compensation, often called **rewind**, starts off. Enable measured-ping or provider timing on the Timing tab, set a bounded lookback within saved history, and use Chrono's returned candidates. The measured-ping option estimates one-way delay from half the server's round-trip measurement; it is not exact transport or display reconstruction. A custom timing provider needs a defensible server rule. A client timestamp alone is insufficient.

## Before shipping your adapter

Use a separate test place and test your actual code with multiple clients. Exercise hits, misses, teams, immunity, stale/missing data, large gaps, duplicate input, replay, cancellations, respawn, teleports, joins/leaves, moving obstacles and exactly-once effects. Check every refusal reason. Add asymmetric inbound/outbound latency, changing delay and packet loss through Studio's Network Simulator. The included synthetic suite does not certify this game-specific work.

Keep the developer GUI gated by your own access checks. It creates no remote debugging protocol. Supply sanitized metrics through your existing approved debug channel if needed.

Continue with [the exact API](integration.md), [ranked limits](math-and-limits.md) and [test reproduction](benchmarks.md).
