# Connector 3.2: full plugin controls

The 25 October 2026 update exposes Core's existing capabilities through the supplied Connector. **Core remains version 3.1.0 with unchanged source and contact math.** Connector and the setup plugin are version 3.2.0. Older benchmark and combat results retain their original labels.

You can configure the connection through the plugin and customize unusual mappings **inside its supplied Hooks, Actions or provider files**. You do not need to replace Connector or write a second integration framework.

## From a fresh installation

1. Install the setup plugin, then use ChronoSetup to choose the initial shape, timing and recording limits. Review and add a named code group.
2. Open **ChronoConnect**, choose that group, and select participants and a position source on **Objects**.
3. Use **Bodies** for named target areas and **Moves** for several visually configured moves, or keep the supplied Actions module.
4. Choose timing and obstacles on **Timing**; choose recording, clocks and bounds on **Recording**.
5. Return to **Objects**, check changes and add the connection package. It supplies enabled server startup and adds no client gameplay RemoteEvent.
6. Link existing server BindableEvents on **Events**, or generate reviewed connection calls on **Calls**. Put unusual argument mappings and outcome rules inside Hooks.
7. Press Play. Inspect the report/Studio guide and actual game outcomes. Test real clients with delay, jitter and loss.

The learning scene on setup page 1 is a working no-code example using anchored objects and practice counters. It does not certify your game's connections.

## Every tab

| Tab | Available controls |
|---|---|
| Objects | Players, extra objects, folder, tag, references, server data without Parts, root/kind names, position source, humanoid checks, simple body and active/team mappings |
| Bodies | Up to 32 named Box/Sphere/Capsule areas, dimensions, XYZ offsets, pitch/yaw/roll, preview, duplicate and remove |
| Moves | Actions module or up to 32 plugin-built profiles; all five query shapes, targets, offsets/rotation, hit window, reach, target limit, eligibility rule, obstacles and per-move Once/Repeated |
| Timing | Present, measured-ping estimate or server provider; maximum lookback, display delay, contact-delivery requirement, static boxes/custom obstacle provider |
| Recording | Heartbeat, Manual or Event; shared clock, rate, retention, maximum gap, global/per-kind/per-object recording limits |
| Events | Accepted move, hit moment, cancel and outcome links; automatic checks, Once/Repeated and automatic repeat interval |
| Calls | Begin, Gate, Query, Resolve, Capture, Track, Untrack, Reset, Inspect, Destroy, Cancel, Finish, Motion and Teleport |
| Test & restore | Runtime report, in-package provider templates, source opening, explicit runtime upgrade, generated-call restore and source-aware removal |

Other tabs offer a settings check/save. Initial installation is reviewed on Objects. Restart Play after changing settings.

## Bodies and moves

Named body areas identify the touched area in each returned contact, such as Head or Body. Empty Bodies uses the simple body on Objects. These shapes attach to the recorded root; they do not follow animated limbs. A position provider can supply animated zones instead. Provider zones take priority over the visual list.

Offsets use the saved root: X right, Y up, Z backward; negative Z is forward. Rotations use degrees in pitch, yaw, roll order. Target zones are Box, Sphere or Capsule. Moves also support Ray and SweptSphere. A swept sphere checks a ball along one straight line; it does not reconstruct every moving target or rotating limb between updates.

The move builder keeps your Actions file. Switch back to Actions for custom profiles or rules inside that supplied file. Each named profile can select its own check mode and rule; the Hook rule calls Hooks.Eligible and refuses by default until customized.

## Earlier positions

Present remains the default. A larger maxRewind alone changes only the ceiling. Enable **Measured ping** or **Provider**, choose a positive ceiling within saved history, and select **targets returned by Chrono contacts**.

Measured ping uses half the server's [GetNetworkPing round-trip measurement](https://create.roblox.com/docs/reference/engine/classes/Player#GetNetworkPing), plus any known display delay you configure. This estimates one-way transport. It does not know exact path asymmetry or the frame the player saw. For data ids, map the owning player inside Hooks.TimingPlayer.

A Timing provider implements Resolve(actor, serverContext, captureTime, maximum), returning one independently approved delay in seconds. The delay stays fixed for that move. Raw client timestamps/delays are insufficient. Negative, nonfinite, over-limit and failing results refuse without a silent clamp. Missing history, gaps, state/shape transitions and teleports still refuse.

**An Allows gate cannot discover a missing candidate.** An existing present-time overlap may miss someone who was inside an earlier hitbox. Use Resolve with an Outcome event/OnContact, or Query's returned contacts. The UI candidate choice records this requirement; it does not automatically rewrite an arbitrary target loop.

Core samples participating actor histories at the selected earlier time. This is not a complete historical movement simulation or an exact reconstruction of the attacker's screen.

## Repeated checks

Once retains the original Connector's one-successful-query policy.

Repeated permits later checks after newer captures, while the same move remains active. A duplicate check at the same saved instant refuses but keeps the move available for a later update. Each target is returned at most once for the whole move. maxTargets is also a whole-move total.

Contact discovery consumes the Core target slot even if a later game rule declines damage. This prevents repeated outcomes from the same contact. Configure multi-hit attacks as separately accepted moves when the design really permits another hit on the same target.

Automatic checking runs during the active window, subject to the configured minimum interval and available captures. It needs an Outcome event and proper cancellation. Query returns evidence without delivering outcomes; Resolve delivers through the selected Outcome event and Hooks.OnContact. A fresh pending Query result can also be delivered through Allows/Resolve. Do not apply your game's outcome twice through different paths.

## Recording and clocks

Heartbeat records after physics and also refreshes on move/query/approval calls, preserving immediate provider checks. The rate controls periodic recording and storage sizing; it is not a cap on all recordings. Storage holds ceil(rate × seconds) + 2 updates per object. Include on-demand calls in the expected rate. Faster actual recording shortens usable history; unavailable times refuse.

Manual/Event gives the server simulation sole recording control. Save once before moves, then after completing each common simulation step. Begin/Query do not secretly capture in these modes. Event uses a selected server BindableEvent with an optional timestamp. Capture timestamps must strictly increase, remain no later than the clock and fit maxGap.

An optional Clock provider returns Now() in seconds. Use that same clock for simulation, timestamps, timing and position providers. Selecting a mode does not create a missing server simulation.

The initial setup's maxSpeed/maxRadius now carry into Connector. These describe root travel per second and the farthest target edge from that root. Kind-specific rows override defaults; optional server attributes ChronoMaxSpeed/ChronoMaxRadius override those; data bindings and Hooks.RecordingLimits can override again. Core bounds still apply. These are admission limits, not proof of legal movement or collision-free travel.

## Objects without Parts

Choose Server data (no Parts) or Players + server data. Add a Registry template inside the package and select it on Objects. Its Snapshots(time) returns a dictionary keyed by stable short text ids:

```luau
return {
    ball = {
        ok = true, -- your server actually calculated/checked this data
        kind = "ball",
        root = ballFrame,
        zones = {Body = Shapes.Sphere(ballFrame, 1)},
        state = {active = true},
        maxSpeed = 160,
        maxRadius = 2,
    },
}
```

Removed registry ids unregister automatically. Alternatively use the generated Track/Capture/Untrack calls. Manual Track defaults to unverified, which refuses hit decisions. Trusted declarations must describe the actual server code; selecting a label does not validate client data.

Snapshots use map coordinates for root/zones and flat simple values for state. Registry and position providers return ok=true only after approval. Callbacks must finish immediately. Errors, yielding and reentry refuse or pause evidence.

After an approved data teleport or provider repair, update game data and call Reset/Discontinuity. For physical objects, Teleport performs the approved movement and resets records. Old moves cannot cross that reset. Finish/Cancel ends the move reference.

## Obstacles

Static boxes uses an explicitly selected Workspace folder/model. CanCollide and CanQuery Parts must be anchored. Their oriented bounding boxes block selected moves regardless of per-actor collision groups. Meshes/unions use conservative bounding boxes and can block visibly empty space. Core bounds apply, including a maximum 512 studs per box dimension.

An observed add/remove/transform/size/collision-group change starts a new coverage period. Earlier queries before that boundary refuse. Unanchored, oversized and excessive obstacle sets refuse coverage. Unsampled changes cannot be reconstructed.

For moving historical cover, terrain or game-specific filtering, customize the World template inside the supplied package. Check(queryTime, currentTime, shape) returns {covered=true, blocked=boolean, fraction=0..1} only when the provider actually knows that time. Unknown cover must not be declared clear.

Core obstacle providers support rays and swept spheres. Box/capsule overlap moves keep their game-specific wall rule in Hooks. Cover wins an exact contact tie.

## Upgrading and keeping custom code

Opening the new UI does not change an installed runtime. Use **Test & restore → Upgrade supplied Connector**, review settings, save and restart Play. Upgrade keeps customized Hooks and Actions. Newly supplied defaults fill missing hook functions. An edited Connector or added Connector extension refuses automatic replacement; use a fresh group to compare.

Legacy settings retain Present/Once and their old recording-limit policy until you deliberately choose reviewed limits on Recording. Save does not silently upgrade runtime. Studio Undo restores object/settings changes. Generated script calls have explicit exact-text Restore records; newer work is protected. Removal refuses customized supplied source and keeps Core/Actions.

Use one group for interacting actors and one ordinary-server singleton. Debug tools may have separate require caches: read the report instead of starting a second runtime. The report and guide display effective timing, recording, obstacle policy, delay and plain-language explanations. Connector.Explain also explains Connector/Core reasons.

## What still belongs to the game

The game accepts authenticated input, checks cooldown/stamina/equipment/ownership, supplies genuinely calculated/checked positions, and applies current block/parry/damage/possession rules. The supplied humanoid checker covers bounded ordinary static-ground movement, not every vehicle, platform, flight mode or anti-cheat requirement.

This update makes Core accessible through the plugin. It does not supply arbitrary animation reconstruction, universal moving-obstacle history, continuous collision detection for every shape, exact attacker-view timing or production certification.

See [raw 3.2 validation and scope](../benchmarks/data/v3.2-connector-2026-10-25.json). Earlier original-Chrono performance comparisons and the [3.1 combat walkthrough](combat-walkthrough.md) retain their original labels.

To reproduce, import ChronoV3Tests.rbxmx into ServerStorage in a disposable place. Let validation refer to ServerStorage.ChronoV3Validation. In Edit, run require(validation.ConnectorExpansionSetup).Prepare(validation) outside any other Undo recording. Press Play with one player and read ReplicatedStorage.__ChronoExpansionResult. Stop Play, then call the same setup module's Cleanup. ConnectorEditorChecks(validation) runs the separate real editor and control-callback checks in Edit. The existing ConnectionTestSetup and UnitTest runner reproduce the older regression suites. Do not run test campaigns in a production game.
