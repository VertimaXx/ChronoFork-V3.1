# Integration contract

**Connector/plugin 3.2.0; unchanged Core 3.1.0.** Most games should use the supplied Connector through [plugin connections](connections.md). Core's lower-level API remains an alternative. Do not start both for the same connection group.

## Supplied Connector API

Use server-side dot calls: `local C = require(game.ServerScriptService.ChronoV3Integration.Connector)`. StartConnection supplies initial startup. Share this ordinary-server instance; debugging tools can have separate require caches.

| Function | Result / meaning |
|---|---|
| C.Start() | Start once from saved settings, linked providers, Hooks and Actions/built moves |
| C.Begin(actor, name?, serverContext?, key?) | Token or nil/reason; after game authorization. Name defaults to Contact. Optional key must be unique among this actor's active moves |
| C.Query(token) | Successful evidence result or nil/reason; no outcome delivery |
| C.Allows(token, target) | Boolean plus contact/reason; approve a target once while evidence is fresh |
| C.Resolve(token) | Query/deliver through Outcome and OnContact; result or nil/reason |
| C.Cancel(token), C.Finish(token) | End move reference; return whether one existed |
| C.Capture(time?) | True on successful common capture, otherwise nil/reason |
| C.Track(id, binding) | Register data id with kind, capture, optional trust/maxSpeed/maxRadius; trust defaults unverified |
| C.Untrack(id) | Remove manually registered data object |
| C.Discontinuity(actor, reason?), C.Resume(actor) | Reset interrupted records after approved change/provider repair |
| C.AllowMotion(actor, velocity, seconds) | Supplied humanoid checker: permit existing server-approved impulse; creates no force |
| C.Teleport(actor, frame) | Perform approved physical teleport and reset records; data objects update game data then use Discontinuity |
| C.Inspect() | Configuration/counters, per-object limits and nested Core report |
| C.Explain(reasonOrResult) | Plain-language Connector/Core explanation |
| C.Destroy() | Disconnect/destroy this runtime; later public calls start it again |

Physical actors/targets use their Model/Part. Data objects use text ids. **Connector contact.target is the game-facing key; contact.id is an internal Core id.** Core-only users receive the ids passed to Core.Track.

Failure forms differ: Connector.Query/Resolve returns nil plus a reason; Core.Query returns an ok=false table. A successful empty contact list is a miss; refusal means insufficient evidence.

Once permits one successful query. Repeated permits later captures during the window. Same-capture duplicates refuse but keep the repeated move available. Every target and maxTargets are consumed across the whole move. A fresh pending Query result can be delivered through Allows/Resolve; do not apply an outcome through both paths.

Heartbeat records periodically and refreshes on move/query/approval calls. Rate sizes storage and schedules periodic samples; it does not cap on-demand samples. Manual/Event records at your explicit simulation call/event. Capture timestamps strictly increase, stay no later than the chosen clock and fit maxGap. Faster-than-configured recording can evict history earlier.

Present is default. Measured-ping estimates one-way delay from half the server's round-trip measurement plus optional known display delay. Provider timing returns a server-approved delay. Earlier modes require positive maxRewind within history and Chrono candidate delivery. The ceiling alone never enables rewind. Core uncertainty checks stay active.

### In-package provider interfaces

| Module | Default interface / contract |
|---|---|
| Position Provider | Snapshot(object,time) → {ok=true,root,zones,state}, after independent calculation/checking |
| Registry | Snapshots(time) → dictionary of text ids with ok/root/zones/state and optional kind/maxSpeed/maxRadius |
| Clock | Now() → finite seconds shared with simulation/providers |
| Timing | Resolve(actor,serverContext,captureTime,maximum) → approved delay from zero to maximum, fixed for the move |
| World | Check(queryTime,currentTime,sweep) → {covered=true,blocked=boolean,fraction=0..1}; unknown history refuses |

Add/open templates through Test & restore. Map existing APIs inside Hooks.ProviderSnapshot, DataSnapshots, Clock, ResolveRewind and WorldCheck. Other Hooks map state, eligibility, bounds, player ownership and event arguments. Callbacks may not yield or reenter Connector.

StaticBoxes supplies conservative bounds for selected anchored Parts. Moving historical cover/terrain needs actual historical data. See [all controls and limits](connector-controls.md).

## Unchanged Core 3.1 reference

The rest of this page describes the low-level API, rather than extra machinery required outside the plugin.

New to these terms? Read [the beginner walkthrough](start-here.md) or open [the searchable handbook](../site/start-here.html) first. The plugin's **Words & errors** explains terms such as authoritative, history, snapshot, root, epoch, interpolation and provider. The reference below keeps precise API names so you can find them in code.

V3.1 adds optional `Core.Explain(reasonOrResult)` with `{code, known, subject, title, meaning, fix}` and public type definitions in `Core.Types` for Studio code suggestions. It does not relax a hit check or approve data. Existing method names and reason codes remain available.

The plugin now also generates `Practice`, an **off-by-default** `RunPractice` Script, and `StartHere` notes. Practice uses made-up values and an immediate hit period; it does not certify real game connections. RunPractice has a Studio-only guard and does not run in published games. Bindings, Actions and Settings remain game-owned editable files; existing installations are not overwritten.

## Four game boundaries

1. **Actor provider:** obtain trusted, atomic `{root, zones, state}` snapshots from the game's existing server simulation or validation layer.
2. **Simulation boundary:** call `Capture(serverTime)` after all participating actors completed that simulation instant.
3. **Action boundary:** the existing server move service authorizes, starts, queries and cancels actions. No gameplay remote or input protocol is supplied.
4. **Outcome boundary:** the game rechecks current eligibility and applies possession, tackle, damage, block, score or other outcomes from covered contacts.

Animations and effects continue through the game's existing move events. An animation marker on an untrusted client cannot authorize a server contact. Root-relative gameplay volumes can deliberately represent a tackle or kick. Exact animated limb zones require a trusted pose provider; V3 does not reconstruct arbitrary game animations.

## Core.new(options)

Server-only construction, with no automatic sampling or instance mutation. Each instance owns independent histories and action handles. Requiring the module creates no actors, remotes or connections.

| Option | Default | Contract |
|---|---:|---|
| seconds | 0.6 | Retention age, 0.05–10 seconds |
| rate | 60 | Capacity sizing, 1–240; not an automatic sampler |
| maxGap | 0.075 | Largest interpolation gap, 0.001–1 seconds |
| maxRewind | 0 | Server timing resolver's maximum, at most retention |
| clock | Workspace:GetServerTimeNow | Finite server timestamp in seconds |
| resolveRewind | absent | `(actorId, approvedContext, captureTime) -> rewindSeconds`; synchronous and bounded |
| world | absent | `(queryTime, now, sweep) -> {covered, blocked, fraction}`; synchronous historical-cover provider |

Ring capacity is `ceil(rate * seconds) + 2`. Calling Capture faster than the configured rate can evict older evidence earlier. Actual coverage is always checked. All clocks/providers must share a timestamp domain. An explicit capture timestamp must be at most maxGap behind the clock and must advance strictly.

Default rewind is zero. Merely supplying a maximum does not enable it. The optional resolver receives game-approved server context, not an automatically trusted client timestamp. The game must authenticate input, measure uncertainty, define fairness and bound compensation. Reject an uncertain request by returning an invalid value/error. V3 rejects it rather than guessing or clamping.

## Actor lifecycle

`chrono:Track(id, {kind, capture, trust, maxSpeed, maxRadius})`

- `id`, `kind`: nonempty strings up to 64 bytes; no id reuse without Untrack.
- `capture(time)`: synchronous atomic snapshot provider for that exact simulation instant.
- `trust`: defaults to `unverified`; declared `serverSimulated` or `serverValidated` permits gameplay evidence.
- `maxSpeed`: finite root-speed bound, 0–4,096 studs/second.
- `maxRadius`: finite bound, 0.001–512 studs, covering every zone's offset from root plus its bounding radius.

Snapshot format:

```luau
{
    root = trustedRootFrame,
    zones = {
        Body = S.Capsule(trustedBodyFrame, 1.5, 5),
        -- Ball = S.Sphere(trustedBallFrame, ballRadius),
    },
    state = {active = true, team = 2, invulnerable = false},
}
```

Frames are world-space; zones are independent gameplay primitives. There is no Humanoid or root-part-name requirement. Maximum 32 zones and 32 flat scalar state entries per actor. Snapshots are validated, copied and frozen. State supports finite numbers, booleans and short strings, not nested objects or Instances.

`Capture` returns `{ok, reason, time, faults}`. An actor provider error, yield, invalid pose, excessive speed or excessive zone extent breaks its history epoch and quarantines it. Other actors can still capture, but any query needing the bad actor rejects. Fix the cause and call `Discontinuity(id, reason)` before resuming; it clears quarantine and invalidates prior evidence. A discontinuity is an explicit game authorization, not an anti-cheat exemption to expose to clients.

`Untrack(id)` removes an actor. Track/Untrack changes invalidate already-created actions globally. This deliberately conservative roster rule prevents removal/id reuse from silently changing historical competition. It can interrupt unrelated actions on joins/leaves; begin a new server-authorized action if your rules allow that.

## Shapes and actions

`Core.Shapes` exports:

```luau
S.Box(frame, size)
S.Sphere(frame, radius)
S.Capsule(frame, radius, totalHeight) -- axis is frame.UpVector; height >= 2*radius
S.Ray(start, finish)                -- zero-radius sweep
S.Sweep(start, finish, radius)
S.At(localShape, worldReferenceFrame)
```

Target zones support boxes, spheres and capsules. Query profiles also support rays and swept spheres. Radius is at most 32 studs, each box dimension and capsule height at most 512, sweep length at most 4,096. Tangency counts. All frames must be finite, orthonormal and right-handed, within the coordinate guard of 10 million studs; this bound is not a precision guarantee at large coordinates.

```luau
local handle, reason = chrono:BeginAction(actorId, {
    shape = S.Box(CFrame.new(0, 0, -3), Vector3.new(4, 4, 5)),
    targets = {"player", "ball"},
    opens = 0.12, closes = 0.35,
    maxTargets = 1, maxReach = 32,
    eligible = function(sourceState, targetState, targetId, targetKind)
        return sourceState.active == true and targetState.active == true
    end,
    world = false,
}, approvedServerContext)
```

The shape is source-root-relative, immutable for that handle, bounded by maxReach. Its world transform comes from sampled source history. For a dynamic game-authored trajectory, authorize separate profiles/handles according to your move service rather than forwarding client shape tables. Active windows use elapsed server capture time. Source history is required when starting the action.

`Query(handle)` accepts no arbitrary historical time, pose or shape override. It uses the latest capture minus the action's fixed approved rewind. A successful result contains `ok=true, reason="covered", time, capturedAt, rewind, source, shape, contacts`. An empty contact list is a covered miss.

Each contact includes id, kind, zone, sampled root/state/epoch/time, travel fraction and distance. For overlaps, fraction and distance are zero; they are not penetration depth or physical surface contact points. Sweeps sort by first travel fraction. Ties sort by actor id, then zone name. At most one zone per actor is returned, and maxTargets limits the entire action, not each query.

All eligible target kinds require covered trusted history. A failed candidate invalidates the whole query, even if another candidate already intersected. No partial contacts or duplicate-suppression changes commit on that failure. Unverified/missing distant actors can therefore reject a query; this version does not use a speculative relevance shortcut.

Successful queries consume that frame for the handle. Repeated queries at that capture time reject; each returned target is consumed for that handle. `EndAction(handle)` cancels it. Automatic expiry is reclaimed on Capture. The game must still prevent creating duplicate actions for the same move request and applying the same returned evidence twice. A rejected game outcome is not automatically retried against that target; implement a deliberate policy in your move service.

## Optional cover and guides

Cover-enabled profiles currently support rays/swept spheres only. The world callback must return `{covered=true, blocked=false, fraction=1}` for a fully checked clear sweep, or `{covered=true, blocked=true, fraction=f}` for a checked blocker at travel fraction f. Unknown coverage returns `{covered=false}` and rejects. Cover wins exact contact ties. The provider must check initial overlap and historical geometry/lifecycle, not merely current map geometry.


`ChronoV3Guides.rbxmx` packages the current in-game learning guide with Core Help and Connector Messages children. Source users can call `Mount(screenGui, optionalMetricsGetter, optionalHelpModule)`. The first two arguments remain compatible. The guide supports Core and Connector inspection counters, selectable-policy explanations and both sets of reason messages. It creates no remote; supply sanitized metrics through an existing authorized debug channel and gate it by developer access. Its presence does not certify an adapter.

`Inspect()` returns a frozen report with actors, **declared** trust, capture state, faults, action count and counters. Accepted queries demonstrate service execution, not correctness of the game outcome handler. GUI configuration checks, runtime counters and trust declarations are deliberately separate.

## Operational boundaries

Maximum 256 actors, 512 live action handles and 4 live actions per source. Query complexity is linear in matching actors times zones, plus contact sorting. Epochs are strict: even exact samples from a previous epoch reject. Discrete state/dimension transitions reject interior interpolation; capture transitions at their actual time and expect conservative refusals around uncertain boundaries.

Callbacks may not yield or reenter the service. Errors are contained; an infinite non-yielding callback cannot be preempted in Luau and can stall Studio/the server. Providers must not mutate gameplay while calculating evidence. Destroy ends the service; there are no implicit connections to disconnect. The example SportsAdapter owns and disconnects its own event connections.

## Documentation checked

- [CFrame.Lerp](https://create.roblox.com/docs/reference/engine/datatypes/CFrame): linear position and shortest-arc rotational interpolation.
- [Plugin.CreateDockWidgetPluginGuiAsync](https://create.roblox.com/docs/reference/engine/classes/Plugin): current dock-widget API.
- [ScriptEditorService.UpdateSourceAsync](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService): edit-time source updates.
- [ChangeHistoryService](https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService): recording, Commit/Cancel, Undo and Redo.
- [Network Simulator](https://create.roblox.com/docs/studio/network-simulator): native transport validation and the six scriptable directional NetworkSettings controls; distinct from this package's synthetic timeline suite.
